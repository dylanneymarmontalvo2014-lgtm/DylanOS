#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${DYLANOS_BUILD_DIR:-$ROOT_DIR/build/live-build}"
DEBIAN_SUITE="${DYLANOS_SUITE:-stable}"
CONFIG_DIR="$BUILD_DIR/config"
INCLUDES="$CONFIG_DIR/includes.chroot"

if [[ "${EUID}" -ne 0 ]]; then
  printf 'Build the ISO as root, for example: sudo %s\n' "$0" >&2
  exit 1
fi
if ! command -v lb >/dev/null 2>&1; then
  printf 'Missing dependency: live-build (command: lb).\n' >&2
  printf 'Install live-build, debootstrap, squashfs-tools, and xorriso, then retry.\n' >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

LB_CONFIG=(
  lb config
  --distribution "$DEBIAN_SUITE"
  --architectures amd64
  --binary-images iso-hybrid
  --archive-areas 'main contrib non-free non-free-firmware'
)
if [[ "${DYLANOS_SERIAL_CONSOLE:-0}" == '1' ]]; then
  LB_CONFIG+=(--bootappend-live 'boot=live components console=tty0 console=ttyS0,115200n8 systemd.show_status=1')
fi
"${LB_CONFIG[@]}"

mkdir -p "$CONFIG_DIR/package-lists" "$INCLUDES" "$CONFIG_DIR/hooks/live"
for category in default development gaming iot; do
  source_list="$ROOT_DIR/packages/$category/packages.list"
  [[ -s "$source_list" ]] || { printf 'Missing package list: %s\n' "$source_list" >&2; exit 1; }
  install -m 0644 "$source_list" "$CONFIG_DIR/package-lists/dylanos-$category.list.chroot"
done

# Baseline identity and machine defaults.
cp -a "$ROOT_DIR/configs/system/rootfs/." "$INCLUDES/"
install -D -m 0755 "$ROOT_DIR/configs/system/rootfs/usr/bin/dylanos-info" "$INCLUDES/usr/bin/dylanos-info"
install -D -m 0755 "$ROOT_DIR/configs/system/rootfs/usr/bin/dylanos-wallpaper" "$INCLUDES/usr/bin/dylanos-wallpaper"
install -D -m 0755 "$ROOT_DIR/configs/system/rootfs/usr/bin/dylanos-welcome" "$INCLUDES/usr/bin/dylanos-welcome"
install -D -m 0644 "$ROOT_DIR/configs/plasma/dylanos-welcome.desktop" "$INCLUDES/usr/share/applications/dylanos-welcome.desktop"
install -D -m 0644 "$ROOT_DIR/configs/plasma/dylanos-welcome-autostart.desktop" "$INCLUDES/etc/xdg/autostart/dylanos-welcome.desktop"
install -D -m 0644 "$ROOT_DIR/configs/bash/dylanos.bashrc" "$INCLUDES/etc/skel/.bashrc"
install -D -m 0644 "$ROOT_DIR/configs/zsh/dylanos.zshrc" "$INCLUDES/etc/skel/.zshrc"
install -D -m 0644 "$ROOT_DIR/configs/plasma/kdeglobals" "$INCLUDES/etc/skel/.config/kdeglobals"

# Branding and desktop themes.
install -D -m 0644 "$ROOT_DIR/branding/icons/dylanos.svg" "$INCLUDES/usr/share/icons/hicolor/scalable/apps/dylanos.svg"
install -D -m 0644 "$ROOT_DIR/branding/wallpapers/dylanos.png" "$INCLUDES/usr/share/backgrounds/dylanos/wallpaper.png"
install -D -m 0644 "$ROOT_DIR/branding/wallpapers/dylanos.svg" "$INCLUDES/usr/share/backgrounds/dylanos/wallpaper.svg"
install -D -m 0644 "$ROOT_DIR/themes/plasma/DylanOS.colors" "$INCLUDES/usr/share/color-schemes/DylanOS.colors"
install -D -m 0644 "$ROOT_DIR/themes/gtk/gtk-3.0-settings.ini" "$INCLUDES/etc/skel/.config/gtk-3.0/settings.ini"
install -D -m 0644 "$ROOT_DIR/themes/gtk/gtk-4.0-settings.ini" "$INCLUDES/etc/skel/.config/gtk-4.0/settings.ini"
install -D -m 0644 "$ROOT_DIR/themes/sddm/10-dylanos.conf" "$INCLUDES/etc/sddm.conf.d/10-dylanos.conf"
install -D -m 0644 "$ROOT_DIR/themes/grub/99-dylanos.cfg" "$INCLUDES/etc/default/grub.d/99-dylanos.cfg"
mkdir -p "$INCLUDES/usr/share/grub/themes/dylanos"
install -m 0644 "$ROOT_DIR/themes/grub/theme.txt" "$INCLUDES/usr/share/grub/themes/dylanos/theme.txt"
install -m 0644 "$ROOT_DIR/themes/grub/background.png" "$INCLUDES/usr/share/grub/themes/dylanos/background.png"
mkdir -p "$INCLUDES/usr/share/plymouth/themes/dylanos"
install -m 0644 "$ROOT_DIR/branding/splash/dylanos.plymouth" "$INCLUDES/usr/share/plymouth/themes/dylanos/dylanos.plymouth"
install -m 0644 "$ROOT_DIR/branding/splash/dylanos.script" "$INCLUDES/usr/share/plymouth/themes/dylanos/dylanos.script"
install -m 0644 "$ROOT_DIR/branding/splash/dylanos.png" "$INCLUDES/usr/share/plymouth/themes/dylanos/dylanos.png"

# Install Calamares configuration and its DylanOS branding.
install -D -m 0644 "$ROOT_DIR/installer/calamares/settings.conf" "$INCLUDES/etc/calamares/settings.conf"
install -D -m 0644 "$ROOT_DIR/installer/calamares/modules/unpackfs.conf" "$INCLUDES/etc/calamares/modules/unpackfs.conf"
mkdir -p "$INCLUDES/etc/calamares/branding/dylanos"
install -m 0644 "$ROOT_DIR/installer/calamares/branding/dylanos/branding.desc" "$INCLUDES/etc/calamares/branding/dylanos/branding.desc"
install -m 0644 "$ROOT_DIR/installer/calamares/branding/dylanos/branding.svg" "$INCLUDES/etc/calamares/branding/dylanos/branding.svg"

# Register the custom Plymouth theme before generating the initramfs.
cat > "$CONFIG_DIR/hooks/live/0100-dylanos-plymouth.hook.chroot" <<'HOOK'
#!/bin/sh
set -eu
theme=/usr/share/plymouth/themes/dylanos/dylanos.plymouth
if command -v update-alternatives >/dev/null 2>&1; then
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$theme" 100
    update-alternatives --set default.plymouth "$theme"
fi
if command -v update-initramfs >/dev/null 2>&1; then
    update-initramfs -u -k all
fi
HOOK
chmod 0755 "$CONFIG_DIR/hooks/live/0100-dylanos-plymouth.hook.chroot"

printf 'Building DylanOS for Debian suite %s in %s\n' "$DEBIAN_SUITE" "$BUILD_DIR"
lb build
printf 'Build complete. Look for the generated ISO under %s.\n' "$BUILD_DIR"
