#!/usr/bin/env bash
set -euo pipefail

trap cleanup EXIT
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
CHROOT="$WORK/chroot"

cleanup() {
    sudo umount -R "$CHROOT/dev" 2>/dev/null || true
    sudo umount -R "$CHROOT/proc" 2>/dev/null || true
    sudo umount -R "$CHROOT/sys" 2>/dev/null || true
}

trap cleanup EXIT

echo "================================="
echo "        DylanOS BUILD"
echo "================================="

sudo rm -rf "$WORK"
mkdir -p "$WORK"

echo "[1/6] Creando Debian Stable..."

sudo debootstrap \
    --variant=minbase \
    --arch=amd64 \
    stable \
    "$CHROOT" \
    http://deb.debian.org/debian

echo "[2/6] Preparando chroot..."

sudo mount --bind /dev "$CHROOT/dev"
sudo mount --bind /dev/pts "$CHROOT/dev/pts"

sudo cp /etc/resolv.conf "$CHROOT/etc/resolv.conf"

sudo chroot "$CHROOT" /bin/bash <<'CHROOT'
set -e

export DEBIAN_FRONTEND=noninteractive

apt update

apt install -y \
    linux-image-amd64 \
    systemd-sysv \
    kde-plasma-desktop \
    sddm \
    calamares \
    sudo \
    network-manager \
    dolphin \
    konsole

systemctl enable sddm
systemctl enable NetworkManager

cat > /etc/os-release <<'EOF'
PRETTY_NAME="DylanOS"
NAME="DylanOS"
ID=dylanos
ID_LIKE=debian
VERSION_ID="1.0"
VERSION="1.0"
HOME_URL="https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS"
EOF

useradd -m -s /bin/bash dylan || true
echo "dylan:dylan" | chpasswd
usermod -aG sudo dylan

apt clean
rm -rf /var/lib/apt/lists/*
CHROOT

echo "[3/6] Integrando branding..."

sudo mkdir -p "$CHROOT/usr/share/dylanos"
sudo cp -a "$ROOT/branding/." "$CHROOT/usr/share/dylanos/" 2>/dev/null || true

echo "[4/6] Integrando configuraciones..."

sudo mkdir -p "$CHROOT/etc/dylanos"
sudo cp -a "$ROOT/configs/." "$CHROOT/etc/dylanos/" 2>/dev/null || true

echo "[5/6] Integrando Calamares..."

sudo mkdir -p "$CHROOT/etc/calamares/branding/dylanos"

sudo cp -a \
    "$ROOT/installer/calamares/dylanos/." \
    "$CHROOT/etc/calamares/branding/dylanos/" \
    2>/dev/null || true

if [ -f "$ROOT/installer/calamares/settings.conf" ]; then
    sudo cp \
        "$ROOT/installer/calamares/settings.conf" \
        "$CHROOT/etc/calamares/settings.conf"
fi

echo "[6/6] Limpiando..."

sudo umount "$CHROOT/dev/pts" 2>/dev/null || true
sudo umount "$CHROOT/dev" 2>/dev/null || true

echo
echo "BUILD COMPLETADO"
echo "Sistema preparado en:"
echo "$WORK/chroot"
