#!/usr/bin/env python3
"""
DylanOS Installer Backend Server.

Instalador propio de DylanOS (sin Calamares). Detecta hardware real,
particiona con parted, extrae el sistema desde el squashfs del medio live,
configura usuarios, locale, teclado y GRUB, y reporta progreso real.

Sirve la interfaz React (dist/) y expone la API REST en 127.0.0.1:8088.
"""

import http.server
import json
import os
import platform
import re
import shlex
import shutil
import signal
import socketserver
import subprocess
import threading
import time
import urllib.parse
from pathlib import Path

PORT = 8088
ROOT_DIR = Path(__file__).resolve().parents[1]
DIST_DIR = ROOT_DIR / "dist"
TARGET_DIR = Path("/target")
LOG_PATH = Path("/var/log/dylanos-install.log") if os.access("/var/log", os.W_OK) else Path("/tmp/dylanos-install.log")
# PID de la ventana nativa (Qt WebEngine) del instalador; la escribe
# installer/native/main.py para que el backend pueda cerrarla.
GUI_PID_PATH = Path("/tmp/dylanos-installer-gui.pid")

SQUASHFS_CANDIDATES = [
    "/run/live/medium/live/filesystem.squashfs",
    "/lib/live/mount/medium/live/filesystem.squashfs",
    "/lib/live/mount/medium/live/vmlinuz.d/live/filesystem.squashfs",
]

# Estado global de la instalación; las transiciones se protegen con
# install_lock y el hilo instalador actualiza el dict de forma atómica.
install_lock = threading.Lock()
install_state = {
    "status": "idle",       # idle | running | complete | error
    "progress": 0,           # 0 - 100
    "phase": 0,             # 0 - 4
    "phaseLabel": "Iniciando instalación...",
    "pkg": "",
    "error": None,
    "detail": "",
    "demo": False,          # True cuando no hay root/disco real (solo vista previa)
    "complete": False,
}


# ────────────────────────────────────────────────────────────────────────
# Utilidades
# ────────────────────────────────────────────────────────────────────────

def log(message):
    """Escribe una línea en el registro de instalación y en stdout."""
    try:
        with LOG_PATH.open("a", encoding="utf-8") as handle:
            handle.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {message}\n")
    except Exception:
        pass
    print(message, flush=True)


def run_cmd(cmd, check=True):
    """Ejecuta un comando shell y devuelve stdout. Registra los fallos."""
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and res.returncode != 0:
        log(f"FALLO: {cmd}\n{res.stderr.strip()}")
        raise RuntimeError(f"Comando falló: {cmd}\nError: {res.stderr.strip()}")
    return res.stdout.strip()


def run_quiet(cmd):
    """Ejecuta un comando ignorando el resultado. Devuelve el código de salida."""
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).returncode


def run_capture(cmd):
    """Ejecuta un comando y devuelve (código de salida, salida stdout+stderr).

    A diferencia de run_cmd/run_quiet permite intentos en cascada (GRUB UEFI →
    sin NVRAM → removable) conservando el mensaje del fallo para el registro.
    """
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return res.returncode, ((res.stdout or "") + (res.stderr or "")).strip()


def close_gui():
    """Cierra la ventana nativa del instalador (Qt WebEngine) si sigue abierta."""
    try:
        pid = int(GUI_PID_PATH.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return
    if pid <= 1 or pid == os.getpid():
        return
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.kill(pid, sig)
        except OSError:
            return
        time.sleep(0.4)
        try:
            os.kill(pid, 0)
        except OSError:
            return


def dir_size_bytes(path):
    """Tamaño total en bytes de un árbol de archivos (du -sb)."""
    try:
        out = run_cmd(f"du -sb {shlex.quote(str(path))}", check=False)
        return int(out.split()[0])
    except Exception:
        return 0


def squashfs_bytes(path):
    """Bytes descomprimidos del squashfs según unsquashfs -s."""
    try:
        out = run_cmd(f"unsquashfs -s {shlex.quote(str(path))}", check=False)
        match = re.search(r"uncompressed size\s+([\d,]+)\s*bytes", out, re.IGNORECASE)
        if not match:
            match = re.search(r"Filesystem size\s+([\d,]+)\s*bytes", out, re.IGNORECASE)
        if match:
            return int(match.group(1).replace(",", ""))
    except Exception:
        pass
    return 0


def update_state(progress, phase, label, pkg="", detail=""):
    """Actualiza el estado de progreso de la instalación."""
    install_state["progress"] = int(progress)
    install_state["phase"] = int(phase)
    install_state["phaseLabel"] = label
    install_state["pkg"] = pkg
    install_state["detail"] = detail


# ────────────────────────────────────────────────────────────────────────
# Catálogos: nombres de la interfaz → códigos reales del sistema
# ────────────────────────────────────────────────────────────────────────

XKB_LAYOUTS = {
    "Español (Latinoamérica)": "latam",
    "Español": "es",
    "English (US)": "us",
    "English (UK)": "gb",
    "Português (Brasil)": "br",
    "Français": "fr",
    "Deutsch": "de",
    "Italiano": "it",
    "Русский": "ru",
    "中文（简体）": "cn",
    "日本語": "jp",
    "한국어": "kr",
    "العربية": "ara",
}

XKB_VARIANTS = {
    ("latam", "Español (Latinoamérica)"): "",
    ("latam", "Español (Latinoamérica) - sin teclas muertas"): "nodeadkeys",
    ("latam", "Español (Latinoamérica) - con tecla Ñ"): "deadtilde",
    ("latam", "Español (Latinoamérica) - Dvorak"): "dvorak",
    ("latam", "Español (Latinoamérica) - Dvorak sin teclas muertas"): "dvorak",
    ("latam", "Español (Latinoamérica) - Colemak"): "colemak",
    ("latam", "Español (Latinoamérica) - Colemak-DH"): "colemak_dh",
    ("es", "Español"): "",
    ("es", "Español - sin teclas muertas"): "nodeadkeys",
    ("es", "Español - Dvorak"): "dvorak",
    ("us", "English (US)"): "",
    ("us", "English (US) - Dvorak"): "dvorak",
    ("us", "English (US) - Colemak"): "colemak",
    ("us", "English (US) - Workman"): "workman",
    ("gb", "English (UK)"): "",
    ("gb", "English (UK) - Dvorak"): "dvorak",
    ("br", "Português (Brasil)"): "",
    ("br", "Português (Brasil) - sin teclas muertas"): "nodeadkeys",
    ("fr", "Français"): "",
    ("fr", "Français (AZERTY)"): "",
    ("fr", "Français - Bépo"): "bepo",
    ("de", "Deutsch"): "",
    ("de", "Deutsch - sin teclas muertas"): "nodeadkeys",
}

XKB_MODELS = {
    "Genérico de 105 teclas (Internacional)": "pc105",
    "Genérico de 104 teclas (EE.UU.)": "pc104",
}

LOCALE_CATALOG = {
    "es_419": "Español (Latinoamérica)",
    "es_ES": "Español (España)",
    "en_US": "English (US)",
    "en_GB": "English (UK)",
    "pt_BR": "Português (Brasil)",
    "fr_FR": "Français",
    "de_DE": "Deutsch",
    "it_IT": "Italiano",
    "ru_RU": "Русский",
    "zh_CN": "中文（简体）",
    "ja_JP": "日本語",
    "ko_KR": "한국어",
    "ar_SA": "العربية",
}

RESERVED_USERS = {
    "root", "daemon", "bin", "sys", "sync", "games", "man", "lp", "mail",
    "news", "uucp", "proxy", "www-data", "backup", "list", "irc", "gnats",
    "nobody", "systemd-network", "systemd-resolve", "messagebus", "sshd",
    "sudo", "dnsmasq", "polkitd", "mysql", "postgres", "Debian-exim",
}


def _supported_locale_codes():
    """Conjunto de locales con codificación UTF-8 disponibles en el sistema."""
    path = Path("/usr/share/i18n/SUPPORTED")
    if not path.exists():
        return set()
    codes = set()
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        parts = line.split()
        if parts and parts[0].endswith(".UTF-8"):
            codes.add(parts[0][: -len(".UTF-8")])
    return codes


# es_419 no existe en Debian/glibc: es el idioma por defecto de DylanOS y debe
# seguir siendo seleccionable, mapeándose al mejor sustituto regional real.
_LOCALE_FALLBACKS = {"es_419": ("es_MX", "es_ES")}


def available_locales():
    """Idiomas del catálogo realmente soportados por el sistema."""
    supported = _supported_locale_codes()
    result = []
    for code, name in LOCALE_CATALOG.items():
        if not supported or code in supported:
            result.append({"code": code, "name": name})
        elif code == "es_419" and "es_MX" in supported:
            # Español (Latinoamérica) se mantiene en la lista: al instalar,
            # normalize_locale lo mapea a es_MX (locale LatAm real de Debian).
            result.append({"code": code, "name": name})
    return result or [{"code": c, "name": n} for c, n in LOCALE_CATALOG.items()]


def normalize_locale(language):
    """Convierte el idioma de la UI en un locale gen válido para locale.gen.

    Si el locale exacto no está soportado se usa el mejor sustituto regional
    conocido (es_419 → es_MX) en lugar de degradar en silencio a es_ES.
    """
    base = language if language.endswith("UTF-8") else f"{language}.UTF-8"
    core = base[: -len(".UTF-8")]
    supported = _supported_locale_codes()
    if not supported or core in supported:
        return base
    for candidate in _LOCALE_FALLBACKS.get(core, ()):
        if candidate in supported:
            return f"{candidate}.UTF-8"
    return "es_ES.UTF-8"


def xkb_layout_code(layout_name):
    return XKB_LAYOUTS.get(layout_name, "latam")


def xkb_variant_code(layout_name, variant_name):
    layout = xkb_layout_code(layout_name)
    return XKB_VARIANTS.get((layout, variant_name), "")


def apply_live_keyboard(layout_name, variant_name, model_name):
    """Aplica la distribución seleccionada al X del medio live (prueba en vivo)."""
    layout = xkb_layout_code(layout_name)
    variant = xkb_variant_code(layout_name, variant_name)
    if not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")):
        return {"ok": True, "layout": layout, "variant": variant, "applied": False}
    cmd = f"setxkbmap {shlex.quote(layout)}"
    if variant:
        cmd += f" -variant {shlex.quote(variant)}"
    run_quiet(cmd)
    return {"ok": True, "layout": layout, "variant": variant, "applied": True}


# ────────────────────────────────────────────────────────────────────────
# Detección de hardware y discos reales
# ────────────────────────────────────────────────────────────────────────

# Columnas de lsblk en orden de preferencia. MOUNTPOINTS (plural) existe desde
# util-linux 2.37 y devuelve una lista; MOUNTPOINT (singular) es el nombre
# antiguo y devuelve una cadena. Se prueban ambas para no depender del kernel.
_LSBLK_COLUMNS = (
    "NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,LABEL",
    "NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,LABEL",
    "NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL",
)


def _safe_int(value, default=0):
    """Convierte cualquier valor de lsblk a entero (int, '123', None, listas).

    `lsblk -J -b` devuelve los tamaños como números, pero algunas variantes y
    dispositivos virtuales entregan cadenas o listas; aquí nunca lanza.
    """
    if isinstance(value, (list, tuple)):
        value = value[0] if value else default
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return default


def _first_mountpoint(value):
    """Normaliza MOUNTPOINT/MOUNTPOINTS a una única cadena de punto de montaje."""
    if isinstance(value, (list, tuple)):
        for item in value:
            if item:
                return str(item)
        return ""
    return str(value).strip() if value else ""


def _human_size(num_bytes):
    """Tamaño legible: GB con un decimal; MB para particiones menores a 1 GB.

    round(bytes/2**30) convierte una ESP de 512 MiB en «0 GB», que en la
    interfaz se lee como partición inexistente.
    """
    gb = num_bytes / (1024 ** 3)
    if gb >= 1:
        return f"{round(gb, 1):g} GB"
    return f"{round(num_bytes / (1024 ** 2))} MB"


def _run_lsblk(columns):
    """Ejecuta lsblk en JSON y devuelve la lista de blockdevices (o lista vacía)."""
    try:
        out = run_cmd(f"lsblk -J -b -o {columns}", check=False)
        return json.loads(out or "{}").get("blockdevices", []) or []
    except Exception:
        return []


def lsblk_devices():
    """Devuelve los blockdevices probando los juegos de columnas disponibles."""
    for columns in _LSBLK_COLUMNS:
        devices = _run_lsblk(columns)
        if devices:
            return devices
    return []


def _is_real_disk(dev):
    """True para discos físicos reales: descarta loop, zram, cdrom y disquetes."""
    name = str(dev.get("name", ""))
    if dev.get("type") != "disk":
        return False
    if any(tag in name for tag in ("loop", "zram")):
        return False
    if name.startswith(("sr", "ram", "fd", "dm-")):
        return False
    return True


# Puntos de montaje donde live-boot expone el medio de instalación.
MEDIUM_MOUNTPOINTS = ("/run/live/medium", "/lib/live/mount/medium")


def _whole_disk_of(source):
    """Devuelve el disco completo al que pertenece una partición (o el propio disco)."""
    name = os.path.basename(source)
    parent = run_cmd(f"lsblk -no PKNAME {shlex.quote(source)}", check=False).strip()
    if parent:
        return f"/dev/{parent}"
    match = re.match(r"^(.*\d+)p\d+$", name)           # nvme0n1p2 → nvme0n1
    if match:
        return f"/dev/{match.group(1)}"
    if re.match(r"^(sd|hd|vd|xvd)[a-z]+\d+$", name):   # sdb1 → sdb
        return f"/dev/{name.rstrip('0123456789')}"
    return source                                      # p. ej. ISO crudo en un USB


def live_medium_disk():
    """Disco completo donde vive el medio live, o None si no aplica.

    Evita que el USB/DVD de instalación se ofrezca como destino de instalación
    y contamine el resumen de almacenamiento. Si el medio no está montado
    (p. ej. arranque toram) devuelve None y no se excluye nada.
    """
    try:
        mounts = Path("/proc/mounts").read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None
    for line in mounts.splitlines():
        fields = line.split()
        if len(fields) < 3:
            continue
        source, mountpoint = fields[0], fields[1]
        if mountpoint in MEDIUM_MOUNTPOINTS and source.startswith("/dev/"):
            return _whole_disk_of(source)
    return None


def real_storage_summary():
    """Capacidad real del equipo y espacio libre, ignorando el medio live.

    En un sistema live `df /` mide el overlay/tmpfs en RAM, no el disco físico,
    así que esa cifra engañaba al instalador. Aquí se suman los discos reales y
    el espacio libre es la diferencia entre el disco y sus particiones. El
    disco del propio medio live no se cuenta. Solo si lsblk no está disponible
    se recurre a `df -BG /`.
    """
    total_bytes = free_bytes = 0
    medium = live_medium_disk()
    for dev in _run_lsblk("NAME,PATH,SIZE,TYPE"):
        if not _is_real_disk(dev):
            continue
        dev_path = dev.get("path") or f"/dev/{dev.get('name', '')}"
        if medium and dev_path == medium:
            continue
        size = _safe_int(dev.get("size"))
        total_bytes += size
        allocated = sum(_safe_int(child.get("size")) for child in dev.get("children", []) or [])
        free_bytes += max(0, size - allocated)

    if total_bytes:
        to_gb = lambda value: round(value / (1024 ** 3))  # noqa: E731
        return f"{to_gb(free_bytes)} GB disponibles de {to_gb(total_bytes)} GB"

    # Respaldo: df sobre / cuando lsblk no responde; se valida que sea numérico
    # para no mostrar basura si otro comando devolvió texto inesperado.
    for line in run_cmd("df -BG /", check=False).splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 4 and parts[1].rstrip("G").isdigit() and parts[3].rstrip("G").isdigit():
            return f"{parts[3].rstrip('G')} GB disponibles de {parts[1].rstrip('G')} GB"
    return "—"


def get_real_system_info():
    """Detecta las características reales del equipo.

    Usa múltiples fuentes con fallback progresivo para que la detección sea
    robusta en entornos live, QEMU y hardware físico variado:
    - Dispositivo: DMI → SMBIOS → nombre genérico
    - CPU: /proc/cpuinfo (siempre disponible en Linux)
    - RAM: /proc/meminfo con redondeo a 2 decimales
    - Almacenamiento: df -BG para el espacio disponible en /
    - GPU: lspci (con fallback si pciutils no está instalado) → /proc/modules
      para detectar módulos de GPU cargados (nvidia/radeon/amdgpu/i915/nouveau)
    """
    # ─── Dispositivo ────────────────────────────────────────────────────────
    device = ""
    _dmi_generic = frozenset({
        "none", "system product name", "to be filled by o.e.m.",
        "default string", "not specified", "unknown", "type1productname",
    })
    for dmi_path in (
        "/sys/devices/virtual/dmi/id/product_name",
        "/sys/class/dmi/id/product_name",
    ):
        if os.path.exists(dmi_path):
            try:
                name = Path(dmi_path).read_text().strip()
                if name and name.lower() not in _dmi_generic:
                    device = name
                    break
            except Exception:
                pass
    if not device:
        # Intentar con el vendor para dar más contexto ("Dell Inspiron")
        vendor = ""
        for vendor_path in (
            "/sys/devices/virtual/dmi/id/sys_vendor",
            "/sys/class/dmi/id/sys_vendor",
        ):
            if os.path.exists(vendor_path):
                try:
                    vendor = Path(vendor_path).read_text().strip()
                    if vendor.lower() in _dmi_generic:
                        vendor = ""
                except Exception:
                    pass
                break
        device = f"{vendor} DylanOS Computer".strip() if vendor else "DylanOS Computer"

    # ─── CPU ────────────────────────────────────────────────────────────────
    cpu = platform.processor() or "Procesador x86_64"
    try:
        cpuinfo = Path("/proc/cpuinfo").read_text()
        for line in cpuinfo.splitlines():
            if "model name" in line:
                cpu = line.split(":", 1)[1].strip()
                break
    except Exception:
        pass

    # ─── RAM ────────────────────────────────────────────────────────────────
    ram = "—"
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemTotal:"):
                kb = int(re.findall(r"\d+", line)[0])
                gb = kb / (1024 * 1024)
                ram = f"{gb:.1f} GB" if gb >= 1 else f"{kb // 1024} MB"
                break
    except Exception:
        pass

    # ─── Almacenamiento ─────────────────────────────────────────────────────
    # Mide los discos físicos reales (no el overlay del medio live) con respaldo
    # a df -BG / cuando lsblk no está disponible.
    storage = real_storage_summary()

    # ─── GPU ─────────────────────────────────────────────────────────────────
    # Estrategia 1: lspci (requiere pciutils; disponible en el live de DylanOS)
    gpu = ""
    try:
        lspci_out = run_cmd("lspci", check=False)
        for line in lspci_out.splitlines():
            if any(tag in line for tag in ("VGA", "3D controller", "Display controller")):
                # Tomar solo la descripción después del segundo ":" para evitar
                # incluir el bus PCI (ej. "00:02.0 VGA compatible controller: Intel...")
                parts = line.split(":", 2)
                gpu = parts[-1].strip() if len(parts) >= 2 else line.strip()
                break
    except Exception:
        pass

    # Estrategia 2: /sys/class/drm para obtener el nombre del driver activo
    if not gpu:
        try:
            drm = Path("/sys/class/drm")
            if drm.exists():
                for card in sorted(drm.iterdir()):
                    driver_link = card / "device" / "driver"
                    if driver_link.is_symlink():
                        driver = driver_link.resolve().name
                        # Mapear driver a nombre legible
                        driver_names = {
                            "i915": "Intel Graphics (i915)",
                            "amdgpu": "AMD Radeon (amdgpu)",
                            "radeon": "AMD Radeon (radeon)",
                            "nvidia": "NVIDIA (nvidia)",
                            "nouveau": "NVIDIA (nouveau)",
                            "virtio-gpu": "VirtIO GPU (QEMU/KVM)",
                            "vmwgfx": "VMware SVGA (vmwgfx)",
                        }
                        gpu = driver_names.get(driver, f"GPU ({driver})")
                        break
        except Exception:
            pass

    # Estrategia 3: módulos del kernel cargados
    if not gpu:
        try:
            modules_text = Path("/proc/modules").read_text()
            module_names = {
                "i915": "Intel Graphics (i915)",
                "amdgpu": "AMD Radeon (amdgpu)",
                "radeon": "AMD Radeon (radeon)",
                "nvidia": "NVIDIA",
                "nouveau": "NVIDIA (nouveau / código abierto)",
                "virtio_gpu": "VirtIO GPU (QEMU/KVM)",
                "vmwgfx": "VMware SVGA",
            }
            loaded = {line.split()[0] for line in modules_text.splitlines() if line.strip()}
            for mod, name in module_names.items():
                if mod in loaded:
                    gpu = name
                    break
        except Exception:
            pass

    if not gpu:
        gpu = "Controlador gráfico estándar"

    return {
        "device": device,
        "cpu": cpu,
        "ram": ram,
        "storage": storage,
        "gpu": gpu,
        "arch": platform.machine(),
    }


def _partition_used_gb(path, mountpoint):
    """Uso real de una partición montada (df), o '—' si no está montada.

    Se usa `df -P` (POSIX) porque la sesión live arranca con es_ES.UTF-8 y la
    cabecera de df se localiza («S.ficheros…»); con -P el formato es estable
    en cualquier idioma y el parseo no depende del texto de la cabecera.
    """
    mountpoint = _first_mountpoint(mountpoint)
    if not mountpoint or mountpoint == "—":
        return "—"
    try:
        lines = run_cmd(f"df -BG -P {shlex.quote(mountpoint)}", check=False).splitlines()
        if len(lines) > 1:
            parts = lines[1].split()
            if len(parts) >= 3:
                used = parts[2].rstrip("G").strip()
                if used.isdigit():
                    return used + " GB"
    except Exception:
        pass
    return "—"


def get_real_disks():
    """Enumera los discos reales (sin loop/zram/cdrom) y sus particiones.

    Lee `lsblk -J` y normaliza todo lo que puede variar entre kernels:
    - El tamaño puede llegar como número, cadena o lista (se usa _safe_int).
    - El punto de montaje puede llegar como MOUNTPOINTS (lista) o MOUNTPOINT.
    - Solo se listan discos (`type == disk`); loop, zram, cdrom y dm se ignoran.

    Nunca lanza: si lsblk no responde, devuelve un marcador para que la interfaz
    muestre el aviso de detección en lugar de quedarse en blanco.
    """
    disks = []
    medium = live_medium_disk()
    for dev in lsblk_devices():
        if not _is_real_disk(dev):
            continue

        dev_name = str(dev.get("name", ""))
        dev_path = dev.get("path") or f"/dev/{dev_name}"
        if medium and dev_path == medium:
            continue
        size_bytes = _safe_int(dev.get("size"))
        size_gb = round(size_bytes / (1024 ** 3))
        model = (dev.get("model") or "").strip()

        partitions = []
        allocated_bytes = 0
        for child in dev.get("children", []) or []:
            child_bytes = _safe_int(child.get("size"))
            allocated_bytes += child_bytes
            mount = (
                _first_mountpoint(child.get("mountpoints"))
                or _first_mountpoint(child.get("mountpoint"))
                or "—"
            )
            partitions.append({
                "device": child.get("path") or f"/dev/{child.get('name')}",
                "type": "Partición",
                "mount": mount,
                "fs": child.get("fstype") or "sin formato",
                "size": _human_size(child_bytes),
                "sizeGB": round(child_bytes / (1024 ** 3), 1),
                "used": _partition_used_gb(child.get("path"), mount),
                "color": "#dc2626" if mount == "/" else "#3b82f6",
            })

        free_bytes = max(0, size_bytes - allocated_bytes)
        if partitions and free_bytes >= (1024 ** 3):
            partitions.append({
                "device": "Espacio libre",
                "type": "—",
                "mount": "—",
                "fs": "—",
                "size": _human_size(free_bytes),
                "sizeGB": round(free_bytes / (1024 ** 3), 1),
                "used": "—",
                "color": "#374151",
            })
        elif not partitions:
            partitions.append({
                "device": "Espacio sin asignar",
                "type": "—",
                "mount": "—",
                "fs": "—",
                "size": f"{size_gb} GB",
                "sizeGB": size_gb,
                "used": "—",
                "color": "#374151",
            })

        disks.append({
            "device": dev_path,
            "size": f"{size_gb} GB",
            "sizeGB": size_gb,
            "model": model or "Unidad de almacenamiento",
            "partitions": partitions,
        })

    if not disks:
        log("lsblk no devolvió discos físicos; se muestra el aviso de detección.")
        disks.append({
            "device": "", "size": "—", "sizeGB": 0,
            "model": "No se detectaron discos físicos",
            "partitions": [],
        })
    return disks


def find_install_partitions(disk):
    """Modo manual: usa la ESP existente y la partición ext4 más grande."""
    root_part, efi_part, root_size = "", "", 0
    for dev in lsblk_devices():
        dev_path = dev.get("path") or f"/dev/{dev.get('name', '')}"
        if dev_path != disk:
            continue
        for child in dev.get("children", []) or []:
            fs = child.get("fstype") or ""
            child_size = _safe_int(child.get("size"))
            # lsblk reporta FAT32 como «vfat»: hay que aceptar ambos nombres.
            if fs.startswith(("fat", "vfat")) and not efi_part:
                efi_part = child.get("path")
            if fs == "ext4" and (child_size > root_size or not root_part):
                root_part, root_size = child.get("path"), child_size
    if not root_part:
        raise RuntimeError(
            "El modo manual necesita una partición ext4 existente en el disco. "
            "Usa el modo automático o prepara el disco antes de instalar."
        )
    return root_part, efi_part


# ────────────────────────────────────────────────────────────────────────
# Validación de usuario y equipo
# ────────────────────────────────────────────────────────────────────────

def validate_user(username, hostname):
    """Valida el nombre de usuario y de equipo con las reglas del sistema."""
    errors = {}

    if not username:
        errors["username"] = "Introduce un nombre de usuario."
    elif not re.match(r"^[a-z_][a-z0-9_-]{0,31}$", username):
        errors["username"] = "Usa solo minúsculas, números y guiones; debe empezar con una letra."
    elif username in RESERVED_USERS:
        errors["username"] = "Ese nombre de usuario está reservado por el sistema."
    else:
        passwd = Path("/etc/passwd")
        if passwd.exists() and re.search(rf"(?m)^{re.escape(username)}:", passwd.read_text(encoding="utf-8", errors="ignore")):
            errors["username"] = "Ya existe una cuenta con ese nombre en este sistema."

    if not hostname:
        errors["hostname"] = "Introduce un nombre para el equipo."
    elif not re.match(r"^[a-zA-Z0-9-]{1,63}$", hostname):
        errors["hostname"] = "Usa solo letras, números y guiones, sin espacios."
    elif hostname.isdigit():
        errors["hostname"] = "El nombre del equipo no puede ser solo números."

    return {
        "ok": not errors,
        "usernameError": errors.get("username", ""),
        "hostnameError": errors.get("hostname", ""),
    }


# ────────────────────────────────────────────────────────────────────────
# Instalación real del sistema
# ────────────────────────────────────────────────────────────────────────

def spawn_progress_monitor(total_bytes, base, span, phase, label):
    """Hilo que mide /target con du y traduce bytes a porcentaje de progreso."""
    stop = threading.Event()

    def monitor():
        last = base
        while not stop.wait(3.0):
            done = dir_size_bytes(TARGET_DIR)
            fraction = min(0.99, done / float(total_bytes)) if total_bytes > 0 else 0.5
            value = int(base + fraction * span)
            if value > last:
                last = value
                update_state(value, phase, label, f"{int(fraction * 100)}% del sistema copiado")

    threading.Thread(target=monitor, daemon=True).start()
    return stop


def create_target_user(username, fullname, password, root_password):
    """Crea la cuenta del usuario en el sistema instalado de forma segura.

    chpasswd recibe las claves por stdin (sin shell), de modo que nunca
    aparecen en la línea de comandos ni en el registro de instalación.
    """
    exists = run_cmd(f"chroot /target id -u {shlex.quote(username)}", check=False)
    if not exists:
        run_cmd(
            f"chroot /target useradd -m -s /bin/bash -c {shlex.quote(fullname or 'DylanOS User')} {shlex.quote(username)}"
        )
    run_quiet(
        f"chroot /target usermod -aG sudo,audio,video,plugdev,netdev,users,input,render {shlex.quote(username)}"
    )

    # Eliminar la cuenta live si el usuario eligió otro nombre.
    if username != "dylan":
        run_quiet("chroot /target userdel -r dylan 2>/dev/null")

    for account, secret in ((username, password), ("root", root_password)):
        if not secret:
            continue
        proc = subprocess.run(
            ["chroot", "/target", "chpasswd"],
            input=f"{account}:{secret}\n",
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(f"No se pudo asignar la contraseña de {account}: {proc.stderr.strip()}")


def enable_target_locale(locale):
    """Habilita el locale elegido en /etc/locale.gen y lo genera en el target."""
    gen = Path("/target/etc/locale.gen")
    lines = gen.read_text(encoding="utf-8", errors="ignore").splitlines() if gen.exists() else []
    updated = []
    enabled = False
    for line in lines:
        if re.match(rf"^#?\s*{re.escape(locale)}\s", line):
            updated.append(re.sub(r"^#\s*", "", line))
            enabled = True
        else:
            updated.append(line)
    if not enabled:
        updated.append(f"{locale} UTF-8")
    gen.write_text("\n".join(updated) + "\n", encoding="utf-8")
    run_quiet("chroot /target locale-gen")
    Path("/target/etc/default/locale").write_text(
        f"LANG={locale}\n", encoding="utf-8"
    )


def write_target_keyboard(layout_name, variant_name, model_name):
    """Escribe /etc/default/keyboard con los códigos XKB reales."""
    layout = xkb_layout_code(layout_name)
    variant = xkb_variant_code(layout_name, variant_name)
    model = XKB_MODELS.get(model_name, "pc105")
    Path("/target/etc/default/keyboard").write_text(
        "# Teclado configurado por el instalador de DylanOS\n"
        f'XKBMODEL="{model}"\n'
        f'XKBLAYOUT="{layout}"\n'
        f'XKBVARIANT="{variant}"\n'
        'XKBOPTIONS=""\n',
        encoding="utf-8",
    )


def cleanup_mounts():
    """Desmonta todo lo montado bajo /target tras éxito o error."""
    for mount in ("dev", "proc", "sys"):
        run_quiet(f"umount -R /target/{mount}")
    run_quiet("umount /target/boot/efi")
    run_quiet("umount -R /target")


def unmount_disk_partitions(disk):
    """Desmonta todas las particiones montadas del disco antes de tocarlo.

    parted se niega a rehacer la tabla (o corrompe datos) si una partición del
    disco sigue en uso, y un montaje viejo en /mnt hace fallar el montaje de
    esa partición en /target.
    """
    for dev in lsblk_devices():
        dev_path = dev.get("path") or f"/dev/{dev.get('name', '')}"
        if dev_path != disk:
            continue
        for child in dev.get("children", []) or []:
            raw = child.get("mountpoints")
            if isinstance(raw, (list, tuple)):
                entries = [str(m) for m in raw if m]
            else:
                single = raw or child.get("mountpoint")
                entries = [str(single)] if single else []
            for mountpoint in entries:
                run_quiet(f"umount {shlex.quote(mountpoint)}")
        break


def wait_for_partitions(disk):
    """Espera a que udev registre las particiones recién creadas.

    Sin udevadm settle, mkfs puede ejecutarse antes de que exista el nodo de
    la partición y fallar con «No such file or directory» en hardware real.
    """
    run_quiet(f"partprobe {shlex.quote(disk)}")
    run_quiet("udevadm settle")
    time.sleep(2)


def perform_installation(config):
    """Ejecuta la secuencia completa de instalación real del sistema."""
    disk = (config.get("disk") or "").strip()
    mode = config.get("mode", "auto")
    user = config.get("user", {})
    username = (user.get("username") or "dylan").strip()
    password = user.get("password") or ""
    root_password = user.get("rootPassword") or password
    fullname = user.get("fullName") or "DylanOS User"
    hostname = (user.get("hostname") or "dylanos").strip()
    keyboard = config.get("keyboard", {})
    layout_name = keyboard.get("layout") or "Español (Latinoamérica)"
    variant_name = keyboard.get("variant") or ""
    model_name = keyboard.get("model") or ""
    language = config.get("language") or "es_419"

    try:
        is_root = os.geteuid() == 0
        is_real_device = bool(disk) and os.path.exists(disk)
        demo = not (is_root and is_real_device)
        install_state["demo"] = demo
        if demo:
            log(f"Vista previa sin escritura (root={is_root}, disco={disk!r} presente={is_real_device}).")
        else:
            log(f"Instalación real: disco={disk} modo={mode} usuario={username} idioma={language}.")

        if not password:
            raise RuntimeError("No se recibió la contraseña del usuario; no es posible crear la cuenta.")

        root_part, efi_part, efi_mounted = "", "", False
        suffix = "p" if "nvme" in disk else ""
        # Particionado automático (GPT): 1) ESP de 512 MiB, 2) partición BIOS
        # boot de 1 MiB — GRUB i386-pc la exige en GPT; sin ella
        # grub-install --target=i386-pc fallaba al final de la instalación —
        # y 3) raíz ext4 con el resto del disco.
        auto_efi = f"{disk}{suffix}1"
        auto_root = f"{disk}{suffix}3"

        # ── Fase 0: preparación del disco y tabla de particiones ──
        update_state(3, 0, "Preparando disco y tabla de particiones...", f"Configurando {disk or 'el disco'}")
        if demo:
            time.sleep(1.0)
        elif mode == "manual":
            root_part, efi_part = find_install_partitions(disk)
            log(f"Modo manual: root={root_part} efi={efi_part or '(sin ESP)'}")
            run_quiet("swapoff -a")
            run_quiet("umount -R /target")
            unmount_disk_partitions(disk)
        else:
            run_quiet("swapoff -a")
            run_quiet("umount -R /target")
            unmount_disk_partitions(disk)
            update_state(8, 0, "Creando particiones EFI y DylanOS...", f"parted {disk}")
            run_cmd(f"parted -s {shlex.quote(disk)} mklabel gpt")
            run_cmd(f"parted -s {shlex.quote(disk)} mkpart ESP fat32 1MiB 513MiB")
            run_cmd(f"parted -s {shlex.quote(disk)} set 1 esp on")
            run_cmd(f"parted -s {shlex.quote(disk)} mkpart BIOSGRUB fat32 513MiB 514MiB")
            run_cmd(f"parted -s {shlex.quote(disk)} set 2 bios_grub on")
            run_cmd(f"parted -s {shlex.quote(disk)} mkpart DylanOS ext4 514MiB 100%")
            wait_for_partitions(disk)
            root_part, efi_part = auto_root, auto_efi

        # ── Fase 1: formateo y montaje ──
        update_state(15, 1, "Formateando particiones del sistema...", f"mkfs {root_part or disk}")
        if demo:
            time.sleep(1.2)
        else:
            if mode != "manual":
                run_cmd(f"mkfs.vfat -F32 -n EFI {shlex.quote(efi_part)}")
                run_cmd(f"mkfs.ext4 -F -L DylanOS {shlex.quote(root_part)}")
            TARGET_DIR.mkdir(parents=True, exist_ok=True)
            run_cmd(f"mount {shlex.quote(root_part)} /target")
            if efi_part:
                run_cmd("mkdir -p /target/boot/efi")
                run_cmd(f"mount {shlex.quote(efi_part)} /target/boot/efi")
                efi_mounted = True

        # ── Fase 2: extracción del sistema base desde el squashfs ──
        update_state(24, 2, "Instalando sistema base DylanOS...", "Descomprimiendo imagen del sistema")
        squashfs = next((c for c in SQUASHFS_CANDIDATES if os.path.exists(c)), None)
        if demo:
            for pct in range(24, 74, 6):
                time.sleep(0.45)
                update_state(pct, 2, "Instalando sistema base (vista previa)...", f"sistema base {pct}%")
        elif squashfs:
            total = squashfs_bytes(squashfs)
            if total <= 0:
                total = 25 * 1024 ** 3
            stop = spawn_progress_monitor(total, 26, 48, 2, "Extrayendo archivos de DylanOS...")
            try:
                run_cmd(f"unsquashfs -f -no-progress -d /target {shlex.quote(squashfs)}")
            finally:
                stop.set()
        else:
            raise RuntimeError("No se encontró filesystem.squashfs del medio live.")

        # ── Fase 3: configuración del sistema instalado ──
        update_state(75, 3, "Configurando sistema, usuarios y red...", "fstab, hostname, locale")
        if demo:
            time.sleep(1.0)
        else:
            root_uuid = run_cmd(f"blkid -s UUID -o value {shlex.quote(root_part)}", check=False)
            fstab = ""
            if root_uuid:
                fstab += f"UUID={root_uuid} / ext4 errors=remount-ro 0 1\n"
            else:
                fstab += f"{root_part} / ext4 errors=remount-ro 0 1\n"
            if efi_mounted:
                efi_uuid = run_cmd(f"blkid -s UUID -o value {shlex.quote(efi_part)}", check=False)
                if efi_uuid:
                    fstab += f"UUID={efi_uuid} /boot/efi vfat umask=0077 0 1\n"
            Path("/target/etc/fstab").write_text(fstab, encoding="utf-8")

            Path("/target/etc/hostname").write_text(f"{hostname}\n", encoding="utf-8")
            Path("/target/etc/hosts").write_text(
                f"127.0.0.1 localhost\n127.0.1.1 {hostname}\n::1 localhost ip6-localhost ip6-loopback\n",
                encoding="utf-8",
            )

            # GRUB, update-grub y update-initramfs necesitan /dev, /proc y /sys
            # dentro del chroot. /sys se replica en cascada (rbind) para que
            # efivarfs quede visible: sin efivarfs, grub-install UEFI no puede
            # escribir el NVRAM y la instalación terminaba con error de GRUB.
            # Se usa run_cmd (no run_quiet): un montaje fallado debe ser un
            # error claro aquí, no un fallo confuso en la fase de GRUB.
            for folder in ("dev", "proc", "sys"):
                run_cmd(f"mkdir -p /target/{folder}")
            run_cmd("mount -t proc proc /target/proc")
            run_cmd("mount --rbind /dev /target/dev")
            run_cmd("mount --make-rslave /target/dev")
            run_cmd("mount --rbind /sys /target/sys")
            run_cmd("mount --make-rslave /target/sys")

            locale = normalize_locale(language)
            update_state(78, 3, "Aplicando idioma y configuración regional...", locale)
            enable_target_locale(locale)

            update_state(80, 3, "Configurando el teclado...", layout_name)
            write_target_keyboard(layout_name, variant_name, model_name)

            update_state(83, 3, f"Creando usuario '{username}'...", f"Nombre: {fullname}")
            create_target_user(username, fullname, password, root_password)

            update_state(87, 3, "Eliminando componentes del medio live...", "live-boot, live-config")
            run_quiet("chroot /target apt-get -y -qq purge live-boot live-config live-config-systemd live-tools")
            run_quiet("chroot /target apt-get -y -qq autoremove --purge")

            update_state(89, 3, "Generando imagen de arranque del kernel...", "update-initramfs")
            run_quiet("chroot /target update-initramfs -u -k all")

        # ── Fase 4: cargador de arranque GRUB ──
        update_state(90, 4, "Instalando cargador de arranque GRUB...", "Configuración UEFI / BIOS")
        if demo:
            time.sleep(1.0)
        else:
            grub_ok = False
            grub_failures = []

            if efi_mounted:
                # UEFI: primero con NVRAM (requiere efivarfs en el chroot); si
                # el medio live arrancó en BIOS o no hay efivars disponibles,
                # se reintenta sin NVRAM y, como último recurso, en modo
                # removable (EFI/BOOT), que cualquier firmware UEFI arranca.
                for extra in ("", "--no-nvram", "--no-nvram --removable"):
                    cmd = (
                        "chroot /target grub-install --target=x86_64-efi "
                        "--efi-directory=/boot/efi --bootloader-id=DylanOS --recheck "
                        + extra
                    ).strip()
                    code, output = run_capture(cmd)
                    if code == 0:
                        grub_ok = True
                        break
                    log(f"GRUB UEFI falló ({extra or 'nvram'}): {output[:300]}")
                    grub_failures.append(f"UEFI {extra or 'nvram'}: {output[:200]}")

            # BIOS (i386-pc) sobre la partición BIOS boot del particionado
            # automático (o la que exista en modo manual). Si UEFI ya quedó
            # instalado, un fallo de la vía BIOS no debe abortar la instalación.
            bios_cmd = f"chroot /target grub-install --target=i386-pc {shlex.quote(disk)}"
            code, output = run_capture(bios_cmd)
            if code == 0:
                grub_ok = True
            else:
                log(f"GRUB BIOS falló: {output[:300]}")
                grub_failures.append(f"BIOS: {output[:200]}")

            if not grub_ok:
                detail = " | ".join(grub_failures)[:400]
                raise RuntimeError(
                    "No se pudo instalar GRUB ni por UEFI ni por BIOS. "
                    f"Comprueba que el disco tenga ESP o partición BIOS boot. Detalle: {detail}"
                )

            # grub.cfg es imprescindible para arrancar: sin él GRUB cae al menú
            # vacío/rescue, así que un fallo aquí sí debe abortar.
            run_cmd("mkdir -p /target/boot/grub")
            run_cmd("chroot /target update-grub")

            update_state(97, 4, "Finalizando escritura en disco...", "sync")
            cleanup_mounts()
            os.sync()

        update_state(
            100, 4,
            "Vista previa completada." if demo else "Instalación completada.",
            "Todo listo para reiniciar",
        )
        install_state["complete"] = True
        install_state["status"] = "complete"
        log("Instalación finalizada correctamente." + (" (vista previa)" if demo else ""))

    except Exception as exc:
        install_state["status"] = "error"
        install_state["error"] = str(exc)[:500]
        log(f"Error en instalación: {exc}")
        cleanup_mounts()


# ────────────────────────────────────────────────────────────────────────
# Servidor HTTP: API REST + archivos estáticos de la interfaz
# ────────────────────────────────────────────────────────────────────────

class InstallerRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Atiende la API REST y sirve la interfaz React desde dist/."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DIST_DIR), **kwargs)

    def log_message(self, fmt, *args):
        log(f"HTTP {self.address_string()} {fmt % args}")

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path

        if path == "/api/health":
            self.send_json({"ok": True, "root": os.geteuid() == 0, "version": "1.0.0"})
        elif path == "/api/system-info":
            self.send_json(get_real_system_info())
        elif path == "/api/disks":
            self.send_json(get_real_disks())
        elif path == "/api/locales":
            self.send_json(available_locales())
        elif path == "/api/keyboards":
            self.send_json({
                "layouts": list(XKB_LAYOUTS.keys()),
                "models": list(XKB_MODELS.keys()),
            })
        elif path == "/api/install/status":
            self.send_json(dict(install_state))
        elif path.startswith("/api/"):
            self.send_json({"error": "Endpoint no encontrado"}, status=404)
        else:
            requested = DIST_DIR / path.lstrip("/")
            if not requested.is_file() and not path.startswith("/assets/"):
                self.path = "/index.html"
            super().do_GET()

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        try:
            payload = json.loads(raw)
        except Exception:
            payload = {}

        if path == "/api/apply-keyboard":
            result = apply_live_keyboard(
                payload.get("layout", "Español (Latinoamérica)"),
                payload.get("variant", ""),
                payload.get("model", ""),
            )
            self.send_json(result)

        elif path == "/api/validate-user":
            self.send_json(validate_user(
                (payload.get("username") or "").strip(),
                (payload.get("hostname") or "").strip(),
            ))

        elif path == "/api/install":
            with install_lock:
                if install_state["status"] == "running":
                    self.send_json({"ok": False, "error": "Instalación ya en progreso"}, status=400)
                    return
                install_state.update({
                    "status": "running",
                    "progress": 0,
                    "phase": 0,
                    "phaseLabel": "Iniciando instalación...",
                    "pkg": "",
                    "error": None,
                    "detail": "",
                    "demo": False,
                    "complete": False,
                })
                threading.Thread(target=perform_installation, args=(payload,), daemon=True).start()
            self.send_json({"ok": True})

        elif path == "/api/reboot":
            self.send_json({"ok": True})
            threading.Thread(
                target=lambda: (time.sleep(1.0), close_gui(), run_quiet("systemctl reboot || reboot")),
                daemon=True,
            ).start()

        elif path == "/api/quit":
            self.send_json({"ok": True})
            def shutdown():
                time.sleep(0.6)
                close_gui()
                log("Instalador cerrado por el usuario.")
                os._exit(0)
            threading.Thread(target=shutdown, daemon=True).start()

        else:
            self.send_json({"error": "Endpoint POST no encontrado"}, status=404)

    def send_json(self, data, status=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)


class InstallerServer(socketserver.ThreadingTCPServer):
    """Servidor multihilo: la ventana pide assets y estado en paralelo."""

    allow_reuse_address = True
    daemon_threads = True


def main():
    log(f"Servidor DylanOS Installer escuchando en http://127.0.0.1:{PORT}")
    log(f"Root: {os.geteuid() == 0 and 'instalación real habilitada' or 'sin root: solo vista previa'}")
    with InstallerServer(("127.0.0.1", PORT), InstallerRequestHandler) as httpd:
        httpd.serve_forever()


if __name__ == "__main__":
    main()
