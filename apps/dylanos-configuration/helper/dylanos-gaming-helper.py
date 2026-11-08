#!/usr/bin/env python3
"""Acciones privilegiadas con lista blanca para DylanOS Gaming.

No acepta comandos arbitrarios. Solo governor (nombres conocidos) y zram
vía systemd de zram-tools. No toca GRUB, particiones, firmware ni drivers.
"""
from __future__ import annotations

import os
import sys
import glob
import re
import subprocess
from pathlib import Path

ALLOWED_GOVERNORS = frozenset(
    {"performance", "schedutil", "ondemand", "powersave", "conservative", "userspace"}
)
ALLOWED_ACTIONS = ("set-governor", "restore-governor", "enable-zram", "disable-zram", "enable-i386")


def sysfs_root() -> Path:
    override = os.environ.get("DYLANOS_GAMING_SYSFS")
    if override:
        return Path(override)
    return Path("/")


def governor_files() -> list[Path]:
    pattern = str(sysfs_root() / "sys/devices/system/cpu/cpu*/cpufreq/scaling_governor")
    return [Path(p) for p in sorted(glob.glob(pattern))]


def read_governors() -> dict[str, str]:
    values = {}
    for path in governor_files():
        try:
            values[str(path)] = path.read_text(encoding="utf-8").strip()
        except OSError:
            continue
    return values


def write_governor(name: str) -> int:
    if name not in ALLOWED_GOVERNORS:
        print(f"Governor no permitido: {name}", file=sys.stderr)
        return 2
    files = governor_files()
    if not files:
        print("Este equipo no expone scaling_governor.", file=sys.stderr)
        return 3
    available: set[str] = set()
    avail_path = files[0].with_name("scaling_available_governors")
    if avail_path.is_file():
        available = set(avail_path.read_text(encoding="utf-8").split())
        if available and name not in available:
            print(f"El governor {name} no está disponible en este hardware.", file=sys.stderr)
            return 4
    wrote = 0
    for path in files:
        try:
            path.write_text(name + "\n", encoding="utf-8")
            wrote += 1
        except OSError as error:
            print(f"No se pudo escribir {path}: {error}", file=sys.stderr)
    return 0 if wrote == len(files) else 5


def restore_governors(payload: str) -> int:
    # payload: path=value;path=value  (solo scaling_governor bajo sysfs)
    restored = 0
    for item in payload.split(";"):
        if not item or "=" not in item:
            continue
        path_text, value = item.split("=", 1)
        path = Path(path_text)
        expected_prefix = str(sysfs_root())
        relative = str(path)[len(expected_prefix):].lstrip("/") if str(path).startswith(expected_prefix) else ""
        if not re.fullmatch(r"sys/devices/system/cpu/cpu[0-9]+/cpufreq/scaling_governor", relative):
            print(f"Ruta rechazada: {path}", file=sys.stderr)
            return 2
        if value not in ALLOWED_GOVERNORS:
            print(f"Governor no permitido: {value}", file=sys.stderr)
            return 2
        try:
            path.write_text(value + "\n", encoding="utf-8")
            restored += 1
        except OSError as error:
            print(f"No se pudo restaurar {path}: {error}", file=sys.stderr)
    return 0 if restored == len(payload.split(";")) else 5


def zram(enable: bool) -> int:
    unit = "zramswap.service"
    action = "enable" if enable else "disable"
    extra = ["--now"]
    try:
        result = subprocess.run(
            ["systemctl", action, *extra, unit],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as error:
        print(f"systemctl no disponible: {error}", file=sys.stderr)
        return 6
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        return result.returncode
    return 0


def enable_i386() -> int:
    try:
        arches = subprocess.run(
            ["dpkg", "--print-foreign-architectures"],
            check=True, capture_output=True, text=True,
        ).stdout.split()
        if "i386" not in arches:
            subprocess.run(["dpkg", "--add-architecture", "i386"], check=True)
        result = subprocess.run(["apt-get", "-o", "Acquire::Retries=3", "update"], check=False)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"No se pudo habilitar i386: {error}", file=sys.stderr)
        return 7
    if result.returncode != 0:
        print("No se pudieron actualizar los índices APT tras habilitar i386.", file=sys.stderr)
        return result.returncode
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2 or argv[1] not in ALLOWED_ACTIONS:
        print("Uso: dylanos-gaming-helper set-governor|restore-governor|enable-zram|disable-zram|enable-i386", file=sys.stderr)
        return 2
    action = argv[1]
    if action == "set-governor":
        if len(argv) != 3:
            print("Uso: dylanos-gaming-helper set-governor <nombre>", file=sys.stderr)
            return 2
        return write_governor(argv[2])
    if action == "restore-governor":
        if len(argv) != 3:
            print("Uso: dylanos-gaming-helper restore-governor <path=valor;...>", file=sys.stderr)
            return 2
        return restore_governors(argv[2])
    if action == "enable-zram":
        return zram(True)
    if action == "disable-zram":
        return zram(False)
    if action == "enable-i386" and len(argv) == 2:
        return enable_i386()
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
