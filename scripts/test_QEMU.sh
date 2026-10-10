#!/usr/bin/env bash
# ==============================================================================
# DylanOS — Script de QA y Prueba en Máquina Virtual QEMU (test_QEMU)
# ==============================================================================
# - Crea o reutiliza un disco virtual QCOW2 de 40 GB.
# - Asigna dinámicamente RAM y núcleos CPU según las capacidades del host físico.
# - Detecta y conecta automáticamente la imagen .iso si está disponible.
# - Reutiliza el disco y estado en ejecuciones posteriores sin sobreescribirlo.
# ==============================================================================

set -euo pipefail

SCRIPT_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="$(cd "$(dirname "$SCRIPT_REAL")/.." && pwd)"
QEMU_BIN="qemu-system-x86_64"
QEMU_IMG="qemu-img"

# Directorio y ruta del disco de la máquina virtual (40 GB dinámicos)
# Si work/ pertenece a root por build.sh, usamos .qemu para no requerir sudo
if [[ -d "$ROOT/work" && -w "$ROOT/work" ]]; then
    VM_DIR="$ROOT/work/qemu"
else
    VM_DIR="$ROOT/.qemu"
fi
VM_DISK="$VM_DIR/dylanos-vm-40g.qcow2"
DISK_SIZE="40G"

show_help() {
    cat <<EOF
Uso: $(basename "$0") [OPCIONES] [RUTA_A_LA_ISO]

Script para inicializar y ejecutar la máquina virtual de DylanOS en QEMU.

Comportamiento:
  - Si es la primera ejecución: crea automáticamente un disco virtual de 40 GB.
  - En ejecuciones posteriores: reutiliza el disco existente sin destruirlo.
  - Detecta automáticamente la imagen ISO generada (ej. DylanOS-1.0-beta-amd64.iso).
  - Asigna memoria RAM y núcleos de CPU proporcionales a tu hardware físico.

Opciones:
  -r, --reset          Elimina el disco actual y crea uno nuevo limpio de 40 GB.
  -d, --disk RUTA      Especifica una ruta personalizada para el archivo de disco .qcow2.
  -i, --iso RUTA       Especifica explícitamente la ruta de la imagen .iso a usar.
  --dry-run            Muestra los parámetros calculados y el comando sin ejecutar QEMU.
  -h, --help           Muestra esta ayuda y termina.

EOF
    exit 0
}

RESET_DISK=false
CUSTOM_ISO=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -r|--reset)
            RESET_DISK=true
            shift
            ;;
        -d|--disk)
            VM_DISK="$2"
            shift 2
            ;;
        -i|--iso)
            CUSTOM_ISO="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            echo "[-] Opción desconocida: $1" >&2
            echo "    Usa --help para ver las opciones disponibles." >&2
            exit 1
            ;;
        *)
            if [[ -z "$CUSTOM_ISO" ]]; then
                CUSTOM_ISO="$1"
            fi
            shift
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 1. Verificar dependencias de QEMU
# ------------------------------------------------------------------------------
if ! command -v "$QEMU_BIN" &>/dev/null; then
    echo "[-] Error: No se encontró '$QEMU_BIN' en el sistema." >&2
    echo "    Instálalo ejecutando: sudo apt install qemu-system-x86" >&2
    exit 1
fi

if ! command -v "$QEMU_IMG" &>/dev/null; then
    echo "[-] Error: No se encontró '$QEMU_IMG' en el sistema." >&2
    echo "    Instálalo ejecutando: sudo apt install qemu-utils" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Gestión del almacenamiento (Disco Virtual de 40 GB)
# ------------------------------------------------------------------------------
mkdir -p "$(dirname "$VM_DISK")"

if [[ "$RESET_DISK" == true && -f "$VM_DISK" ]]; then
    echo "[!] Advertencia: Reseteando disco de la máquina virtual..."
    rm -f "$VM_DISK"
fi

if [[ ! -f "$VM_DISK" ]]; then
    echo "======================================================================"
    echo "[+] Primera ejecución: Creando nueva máquina virtual con disco de $DISK_SIZE..."
    echo "    Ruta: $VM_DISK"
    echo "    Formato: QCOW2 (crecimiento dinámico de almacenamiento)"
    echo "======================================================================"
    "$QEMU_IMG" create -f qcow2 "$VM_DISK" "$DISK_SIZE"
    echo "[✓] Disco virtual de $DISK_SIZE creado exitosamente."
else
    echo "======================================================================"
    echo "[i] Máquina virtual existente detectada:"
    echo "    Ruta: $VM_DISK"
    echo "    Reutilizando disco y estado guardado previamente."
    echo "======================================================================"
fi

# ------------------------------------------------------------------------------
# 3. Asignación dinámica de recursos según la máquina física
# ------------------------------------------------------------------------------
# CPU: asigna núcleos de acuerdo a los procesadores disponibles del host
HOST_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 2)
if [[ $HOST_CORES -ge 8 ]]; then
    VM_CORES=$(( HOST_CORES / 2 ))
elif [[ $HOST_CORES -ge 4 ]]; then
    VM_CORES=2
elif [[ $HOST_CORES -ge 2 ]]; then
    VM_CORES=2
else
    VM_CORES=1
fi

# RAM: asigna aproximadamente la mitad de la memoria física disponible
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 4194304)
TOTAL_MEM_MB=$(( TOTAL_MEM_KB / 1024 ))

if [[ $TOTAL_MEM_MB -ge 24000 ]]; then
    VM_RAM_MB=8192
elif [[ $TOTAL_MEM_MB -ge 12000 ]]; then
    VM_RAM_MB=6144
elif [[ $TOTAL_MEM_MB -ge 7000 ]]; then
    VM_RAM_MB=4096
elif [[ $TOTAL_MEM_MB -ge 5000 ]]; then
    VM_RAM_MB=3072
else
    VM_RAM_MB=2048
fi

echo "[i] Diagnóstico del Host Físico:"
echo "    - Núcleos de CPU host:  $HOST_CORES núcleos -> Asignados a la VM: $VM_CORES núcleos"
echo "    - Memoria RAM host:     $TOTAL_MEM_MB MB -> Asignados a la VM: $VM_RAM_MB MB"

# ------------------------------------------------------------------------------
# 4. Aceleración por Hardware (KVM)
# ------------------------------------------------------------------------------
if [[ ! -e /dev/kvm ]]; then
    sudo modprobe kvm 2>/dev/null || true
    sudo modprobe kvm_intel 2>/dev/null || true
    sudo modprobe kvm_amd 2>/dev/null || true
fi

KVM_FLAGS=()
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    echo "[+] Aceleración por hardware KVM disponible y activa (/dev/kvm)."
    KVM_FLAGS+=("-enable-kvm" "-cpu" "host")
else
    echo "[!] Nota: /dev/kvm no tiene permisos directos o no está activo."
    echo "    Usando emulación TCG x86_64 con CPU optimizada."
    KVM_FLAGS+=("-cpu" "max")
fi

# ------------------------------------------------------------------------------
# 5. Detección automática de la imagen ISO
# ------------------------------------------------------------------------------
ISO_PATH=""
if [[ -n "$CUSTOM_ISO" ]]; then
    if [[ -f "$CUSTOM_ISO" ]]; then
        ISO_PATH="$CUSTOM_ISO"
    else
        echo "[-] Error: La ISO especificada '$CUSTOM_ISO' no existe." >&2
        exit 1
    fi
else
    # Buscar ISO oficial por nombre en la raíz del proyecto
    if [[ -f "$ROOT/DylanOS-1.0-beta-amd64.iso" ]]; then
        ISO_PATH="$ROOT/DylanOS-1.0-beta-amd64.iso"
    else
        # Búsqueda de cualquier .iso generada en la raíz
        for candidate in "$ROOT"/*.iso; do
            if [[ -f "$candidate" ]]; then
                ISO_PATH="$candidate"
                break
            fi
        done
    fi
fi

MEDIA_FLAGS=()
if [[ -n "$ISO_PATH" && -f "$ISO_PATH" ]]; then
    echo "[+] ISO detectada automáticamente:"
    echo "    $ISO_PATH"
    MEDIA_FLAGS+=(
        "-drive" "file=$VM_DISK,if=virtio,format=qcow2"
        "-cdrom" "$ISO_PATH"
        "-boot" "menu=on,order=dc"
    )
else
    echo "[i] No se detectó ninguna imagen .iso en la raíz del proyecto."
    echo "    Arrancando directamente desde el disco virtual de 40 GB..."
    MEDIA_FLAGS+=(
        "-drive" "file=$VM_DISK,if=virtio,format=qcow2"
        "-boot" "menu=on,order=c"
    )
fi

# ------------------------------------------------------------------------------
# 6. Parámetros de Dispositivos y Periféricos
# ------------------------------------------------------------------------------
DEVICE_FLAGS=(
    "-m" "${VM_RAM_MB}M"
    "-smp" "$VM_CORES"
    "-vga" "virtio"
    "-display" "default,show-cursor=on"
    "-usb"
    "-device" "usb-tablet"
    "-netdev" "user,id=net0"
    "-device" "virtio-net-pci,netdev=net0"
)

# Soporte de audio opcional (si el host cuenta con PulseAudio o ALSA)
if [[ -n "${PULSE_SERVER:-}" || -S "/run/user/$(id -u)/pulse/native" ]]; then
    DEVICE_FLAGS+=("-audiodev" "pa,id=snd0" "-device" "intel-hda" "-device" "hda-duplex,audiodev=snd0")
fi

# ------------------------------------------------------------------------------
# 7. Ejecución de QEMU
# ------------------------------------------------------------------------------
CMD=("$QEMU_BIN" "${KVM_FLAGS[@]}" "${MEDIA_FLAGS[@]}" "${DEVICE_FLAGS[@]}")

echo "======================================================================"
echo "[+] Iniciando Máquina Virtual DylanOS..."
echo "    Comando: ${CMD[*]}"
echo "======================================================================"

if [[ "$DRY_RUN" == true ]]; then
    echo "[i] Modo --dry-run activo. No se inicia la máquina virtual."
    exit 0
fi

exec "${CMD[@]}"
