#!/usr/bin/env bash
# Smoke test del arranque live: mide desde el kernel hasta graphical.target y SDDM.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${DYLANOS_VERSION:-1.0-beta}"
ISO="${1:-$ROOT/DylanOS-${VERSION}-amd64.iso}"
BOOT_TIMEOUT="${DYLANOS_QEMU_BOOT_TIMEOUT:-420}"
[[ -f "$ISO" ]] || { echo "No existe la ISO: $ISO" >&2; exit 1; }
[[ "$BOOT_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || { echo 'DYLANOS_QEMU_BOOT_TIMEOUT debe ser un entero positivo.' >&2; exit 2; }
for tool in qemu-system-x86_64 xorriso; do
    command -v "$tool" >/dev/null || { echo "Falta herramienta: $tool" >&2; exit 1; }
done
TMP="$(mktemp -d)"
QEMU_PID=""
# shellcheck disable=SC2317 # Invoked by the EXIT trap below.
cleanup() {
    if [[ -n "$QEMU_PID" ]] && kill -0 "$QEMU_PID" 2>/dev/null; then
        kill "$QEMU_PID" 2>/dev/null || true
        wait "$QEMU_PID" 2>/dev/null || true
    fi
    rm -rf "$TMP"
}
trap cleanup EXIT
SERIAL_LOG="$TMP/serial.log"
xorriso -osirrox on -indev "$ISO" \
    -extract /live/vmlinuz "$TMP/vmlinuz" \
    -extract /live/initrd.img "$TMP/initrd.img" >/dev/null 2>&1
[[ -s "$TMP/vmlinuz" && -s "$TMP/initrd.img" ]] || { echo 'No se pudo extraer el kernel/initramfs de la ISO.' >&2; exit 1; }
# Arranca los mismos kernel/initramfs del artefacto, con salida serial y Plymouth
# desactivado para que el marcador de systemd sea observable sin pantalla.
qemu-system-x86_64 \
    -machine pc,accel=tcg -cpu qemu64 -m 4096 -smp 2 \
    -kernel "$TMP/vmlinuz" -initrd "$TMP/initrd.img" \
    -append 'boot=live components hostname=dylanos username=dylan user-fullname="DylanOS Live" locales=es_ES.UTF-8 keyboard-layouts=latam plymouth.enable=0 console=tty0 console=ttyS0 systemd.show_status=1 systemd.log_color=no' \
    -cdrom "$ISO" -vga virtio -display none -monitor none -serial "file:$SERIAL_LOG" \
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0 -no-reboot \
    >"$TMP/qemu.log" 2>&1 &
QEMU_PID=$!
SECONDS=0
boot_markers_reached() {
    python3 "$ROOT/scripts/check_boot_log.py" "$SERIAL_LOG"
}
while (( SECONDS < BOOT_TIMEOUT )); do
    if boot_markers_reached; then
        echo "Arranque live QEMU: graphical.target y SDDM alcanzados en ${SECONDS}s (kernel→greeter service)."
        exit 0
    fi
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        echo 'QEMU terminó antes de completar el arranque.' >&2
        cat "$TMP/qemu.log" >&2
        tail -n 100 "$SERIAL_LOG" >&2 || true
        exit 1
    fi
    sleep 1
done
# Comprueba una última vez al salir del bucle para no perder marcadores escritos
# justo antes del último ciclo de sleep.
if boot_markers_reached; then
    echo "Arranque live QEMU: graphical.target y SDDM alcanzados en ${SECONDS}s (kernel→greeter service)."
    exit 0
fi
echo "Timeout: no se alcanzaron graphical.target y SDDM en ${BOOT_TIMEOUT}s." >&2
tail -n 160 "$SERIAL_LOG" >&2 || true
cat "$TMP/qemu.log" >&2
exit 1
