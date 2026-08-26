#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
CHROOT="$WORK/chroot"
ISO="$ROOT/iso"

echo "================================="
echo "        DylanOS ISO"
echo "================================="

if [ ! -d "$CHROOT" ]; then
    echo "ERROR: Primero ejecuta scripts/build.sh"
    exit 1
fi

rm -rf "$ISO"
mkdir -p "$ISO/live"

echo "[1/4] Creando filesystem..."

sudo mksquashfs \
    "$CHROOT" \
    "$ISO/live/filesystem.squashfs" \
    -e boot \
    -comp xz \
    -b 1M

echo "[2/4] Copiando kernel..."

KERNEL=$(find "$CHROOT/boot" -name 'vmlinuz-*' | head -1)
INITRD=$(find "$CHROOT/boot" -name 'initrd.img-*' | head -1)

sudo cp "$KERNEL" "$ISO/live/vmlinuz"
sudo cp "$INITRD" "$ISO/live/initrd.img"

echo "[3/4] Creando estructura ISO..."

mkdir -p "$ISO/boot/grub"

cat > "$ISO/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0

menuentry "DylanOS" {
    linux /live/vmlinuz boot=live
    initrd /live/initrd.img
}
EOF

echo "[4/4] Generando ISO..."

grub-mkrescue \
    -o "$ROOT/DylanOS-1.0-amd64.iso" \
    "$ISO"

echo
echo "================================="
echo "ISO GENERADA"
echo "================================="
ls -lh "$ROOT/DylanOS-1.0-amd64.iso"
