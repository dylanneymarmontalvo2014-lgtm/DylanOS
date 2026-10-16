#!/usr/bin/env bash
# Build in an isolated mount namespace; the host desktop is never modified.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ${1:-} != --inside ]]; then
    exec sudo unshare --mount --propagation private bash "$0" --inside "$@"
fi
shift
PROFILE=development
RESUME=false
for arg in "$@"; do
    case "$arg" in
        --resume) RESUME=true ;;
        --minimal) PROFILE=default ;;
        *) echo "Uso: $0 [--resume] [--minimal]" >&2; exit 2 ;;
    esac
done
WORK="$ROOT/work"
CHROOT="$WORK/chroot"
mkdir -p "$WORK"
exec 9>"$WORK/build.lock"
flock -n 9 || { echo "Ya hay una construcción en marcha." >&2; exit 1; }
for tool in debootstrap chroot mount python3; do
    command -v "$tool" >/dev/null || { echo "Falta herramienta: $tool" >&2; exit 1; }
done
if [[ -e "$CHROOT" && $RESUME != true ]]; then
    echo "Existe $CHROOT. Usa --resume para continuar; no se borrará automáticamente." >&2
    exit 1
fi
rm -f "$WORK/build-complete"
cleanup() {
    umount -R "$CHROOT/dev" 2>/dev/null || true
    umount "$CHROOT/proc" 2>/dev/null || true
    umount -R "$CHROOT/sys" 2>/dev/null || true
}
trap cleanup EXIT
if [[ ! -f "$CHROOT/etc/debian_version" ]]; then
    gpg --batch --yes --dearmor -o "$WORK/debian-trixie.gpg" "$ROOT/configs/keys/debian-trixie.asc"
    debootstrap --force-check-gpg --keyring="$WORK/debian-trixie.gpg" --variant=minbase --arch=amd64 trixie "$CHROOT" https://deb.debian.org/debian
fi
mount --rbind /dev "$CHROOT/dev"
mount --make-rslave "$CHROOT/dev"
mount -t proc proc "$CHROOT/proc"
mount --rbind /sys "$CHROOT/sys"
mount --make-rslave "$CHROOT/sys"
cp -L /etc/resolv.conf "$CHROOT/etc/resolv.conf"
cat > "$CHROOT/etc/apt/sources.list" <<'EOF'
deb https://deb.debian.org/debian trixie main contrib non-free-firmware
deb https://deb.debian.org/debian trixie-updates main contrib non-free-firmware
deb https://security.debian.org/debian-security trixie-security main contrib non-free-firmware
EOF
mkdir -p "$CHROOT/tmp/dylanos-packages"
printf '#!/bin/sh\nexit 101\n' > "$CHROOT/usr/sbin/policy-rc.d"
chmod +x "$CHROOT/usr/sbin/policy-rc.d"
# shellcheck source=scripts/lib/packages.sh
. "$ROOT/scripts/lib/packages.sh"
groups=(default build)
if [[ "$PROFILE" == development ]]; then groups+=(development); fi
rm -f "$CHROOT/tmp/dylanos-packages/"*.list "$CHROOT/tmp/dylanos-packages/"*.setup-repos.sh
for group in "${groups[@]}"; do
    parse_package_list "$ROOT/packages/$group/packages.list" > "$CHROOT/tmp/dylanos-packages/$group.list"
    if [[ -f "$ROOT/packages/$group/setup-repos.sh" ]]; then
        cp "$ROOT/packages/$group/setup-repos.sh" "$CHROOT/tmp/dylanos-packages/$group.setup-repos.sh"
    fi
done
chroot "$CHROOT" /bin/bash <<'CHROOT_SCRIPT'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=3 update
for setup in /tmp/dylanos-packages/*.setup-repos.sh; do
    if [[ -e "$setup" ]]; then bash "$setup"; fi
done
apt-get -o Acquire::Retries=3 update
for list in /tmp/dylanos-packages/*.list; do
    xargs -r -a "$list" apt-get -o Acquire::Retries=3 install -y
done
sed -i 's/^# es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/; s/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=es_ES.UTF-8
systemctl enable sddm NetworkManager
passwd -l root
CHROOT_SCRIPT
python3 "$ROOT/scripts/stage.py" "$CHROOT"
mkdir -p "$CHROOT/tmp/dylanos-src"
for app in calculator dylanos-app-center; do
    mkdir -p "$CHROOT/tmp/dylanos-src/$app"
    cp -a "$ROOT/apps/$app/CMakeLists.txt" "$ROOT/apps/$app/src" "$ROOT/apps/$app/qml" "$CHROOT/tmp/dylanos-src/$app/"
    for extra in data icons dylanos-app-center.desktop; do
        if [[ -e "$ROOT/apps/$app/$extra" ]]; then cp -a "$ROOT/apps/$app/$extra" "$CHROOT/tmp/dylanos-src/$app/"; fi
    done
    chroot "$CHROOT" cmake -S "/tmp/dylanos-src/$app" -B "/tmp/dylanos-src/$app/build" -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
    chroot "$CHROOT" cmake --build "/tmp/dylanos-src/$app/build" --parallel 2
    chroot "$CHROOT" cmake --install "/tmp/dylanos-src/$app/build"
done
# DylanOS Store: fork nativo de Discover (libdiscover + UI del prototipo).
mkdir -p "$CHROOT/tmp/dylanos-src/dylanos-store" "$CHROOT/tmp/dylanos-src/catalog"
cp -a "$ROOT/apps/dylanos-store/src/." "$CHROOT/tmp/dylanos-src/dylanos-store/"
cp -a "$ROOT/apps/dylanos-store/catalog/store.db" "$CHROOT/tmp/dylanos-src/catalog/"
chroot "$CHROOT" cmake -S /tmp/dylanos-src/dylanos-store -B /tmp/dylanos-src/dylanos-store/build -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
chroot "$CHROOT" cmake --build /tmp/dylanos-src/dylanos-store/build --parallel 2
chroot "$CHROOT" ctest --test-dir /tmp/dylanos-src/dylanos-store/build --output-on-failure
chroot "$CHROOT" cmake --install /tmp/dylanos-src/dylanos-store/build
chroot "$CHROOT" /bin/bash <<'CHROOT_SCRIPT'
set -euo pipefail
plymouth-set-default-theme dylanos
update-initramfs -u -k all
update-desktop-database /usr/share/applications
# Los -dev exclusivos de la DylanOS Store no se envían en el ISO.
apt-get -y purge libflatpak-dev libostree-dev libappstreamqt-dev libpackagekitqt6-dev \
    qcoro-qt6-dev kirigami-addons-dev libkirigami-dev libkf6xmlgui-dev \
    libkf6idletime-dev libkf6statusnotifieritem-dev libkf6notifications-dev \
    libkf6crash-dev libkf6dbusaddons-dev libkf6archive-dev qt6-svg-dev \
    libkf6iconthemes-dev libkf6auth-dev
apt-get clean
rm -f /usr/sbin/policy-rc.d
rm -rf /tmp/dylanos-packages /tmp/dylanos-src
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id
CHROOT_SCRIPT
# shellcheck disable=SC2016
chroot "$CHROOT" dpkg-query -W -f='${Package} ${Version}\n' > "$WORK/packages.manifest"
printf '%s\n' "$PROFILE" > "$WORK/profile"
touch "$WORK/build-complete"
echo "Sistema construido: $CHROOT. Siguiente paso: bash scripts/iso.sh"
