#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO="$ROOT/DylanOS-1.0-beta-amd64.iso"
[[ -f "$ISO" ]] || { echo 'No existe la ISO beta. Ejecuta scripts/build.sh y scripts/iso.sh.' >&2; exit 1; }
(cd "$ROOT" && sha256sum -c "$(basename "$ISO").sha256")
xorriso -indev "$ISO" -report_el_torito plain 2>&1
for file in /live/filesystem.squashfs /live/vmlinuz /live/initrd.img /boot/grub/grub.cfg /.disk/info; do
    result="$(xorriso -indev "$ISO" -ls "$file" 2>/dev/null)"
    [[ -n "$result" ]] || { echo "Falta $file" >&2; exit 1; }
done
echo 'Estructura de ISO e integridad: OK. El arranque y la instalación requieren QA en VM.'
