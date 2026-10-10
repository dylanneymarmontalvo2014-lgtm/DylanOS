#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID -ne 0 ]]; then exec sudo bash "$0" "$@"; fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
CHROOT="$WORK/chroot"
IMAGE="$WORK/iso"
OUTPUT="$ROOT/DylanOS-1.0-beta-amd64.iso"
[[ -f "$WORK/build-complete" ]] || { echo 'Primero completa scripts/build.sh' >&2; exit 1; }
exec 9>"$WORK/build.lock"
flock -n 9 || { echo 'La construcción del sistema todavía está en marcha.' >&2; exit 1; }
for tool in mksquashfs grub-mkrescue xorriso; do
    command -v "$tool" >/dev/null || { echo "Falta herramienta: $tool" >&2; exit 1; }
done
if findmnt -rn -o TARGET | grep -q "^$CHROOT/"; then
    echo 'El chroot tiene montajes activos. Desmóntalos antes de generar la ISO.' >&2
    exit 1
fi
mkdir -p "$IMAGE/live" "$IMAGE/boot/grub"
# Keep /boot in the filesystem: the installed system needs its own kernel.
sudo mksquashfs "$CHROOT" "$IMAGE/live/filesystem.squashfs.new" -noappend -comp zstd -Xcompression-level 15 -processors 2 -e dev proc sys run tmp
sudo mv "$IMAGE/live/filesystem.squashfs.new" "$IMAGE/live/filesystem.squashfs"
KERNEL="$(find "$CHROOT/boot" -maxdepth 1 -name 'vmlinuz-*' -printf '%f\n' | sort -V | tail -1)"
[[ -n "$KERNEL" ]] || { echo 'No se encontró el kernel.' >&2; exit 1; }
INITRD="initrd.img-${KERNEL#vmlinuz-}"
[[ -f "$CHROOT/boot/$INITRD" ]] || { echo "Falta initrd para $KERNEL" >&2; exit 1; }
install -m 0644 "$CHROOT/boot/$KERNEL" "$IMAGE/live/vmlinuz"
install -m 0644 "$CHROOT/boot/$INITRD" "$IMAGE/live/initrd.img"
cp "$WORK/packages.manifest" "$IMAGE/live/filesystem.packages"
mkdir -p "$IMAGE/boot/grub/themes/dylanos" "$IMAGE/boot/grub/fonts" "$IMAGE/.disk"
cp -a "$CHROOT/usr/share/grub/themes/dylanos/." "$IMAGE/boot/grub/themes/dylanos/"
if [[ -f "$CHROOT/usr/share/grub/unicode.pf2" ]]; then
    cp "$CHROOT/usr/share/grub/unicode.pf2" "$IMAGE/boot/grub/fonts/unicode.pf2"
fi
printf 'DylanOS 1.0 Beta amd64\n' > "$IMAGE/.disk/info"
cat > "$IMAGE/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=0

menuentry "Instalar DylanOS 1.0 Beta" {
    linux /live/vmlinuz boot=live components hostname=dylanos username=dylan user-fullname="DylanOS Live" locales=es_ES.UTF-8 keyboard-layouts=latam quiet splash
    initrd /live/initrd.img
}
EOF
grub-mkrescue -o "$OUTPUT.partial" "$IMAGE"
mv "$OUTPUT.partial" "$OUTPUT"
(cd "$ROOT" && sha256sum "$(basename "$OUTPUT")" > "$(basename "$OUTPUT").sha256")
echo "ISO creada: $OUTPUT"
