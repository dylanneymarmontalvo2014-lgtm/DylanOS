#!/usr/bin/env bash
# Build in an isolated mount namespace; the host desktop is never modified.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
# shellcheck source=scripts/lib/lock.sh
. "$ROOT/scripts/lib/lock.sh"
VERSION="${DYLANOS_VERSION:-1.0-beta}"
for arg in "$@"; do
    case "$arg" in
        --version=*) VERSION="${arg#*=}" ;;
    esac
done
if [[ ! "$VERSION" =~ ^([0-9]+\.[0-9]+\.[0-9]+([+-][A-Za-z0-9.-]+)?|1\.0-beta)$ ]]; then
    echo "Versión DylanOS inválida: $VERSION" >&2
    exit 2
fi
if [[ ${1:-} != --inside && $EUID -eq 0 ]]; then
    echo "No ejecutes scripts/build.sh con sudo; el script eleva privilegios internamente." >&2
    echo "Usa: ./scripts/build.sh [--resume] [--minimal]" >&2
    exit 2
fi
CPU_COUNT="$(nproc 2>/dev/null || printf '2')"
DEFAULT_BUILD_JOBS="$CPU_COUNT"
if (( DEFAULT_BUILD_JOBS > 4 )); then DEFAULT_BUILD_JOBS=4; fi
BUILD_JOBS="${DYLANOS_BUILD_JOBS:-$DEFAULT_BUILD_JOBS}"
if [[ ${1:-} != --inside ]]; then
    # Asegurar exclusión antes de tocar permisos o el directorio de artefactos.
    dylanos_acquire_build_lock "$ROOT" "Ya hay una construcción en marcha."
    # La fase elevada puede haber dejado work/ propiedad de root en builds previos.
    mkdir -p "$WORK"
    WORK_OWNER="$(stat -c '%u' "$WORK")"
    if [[ "$WORK_OWNER" != "$(id -u)" || ! -w "$WORK" ]]; then
        sudo chown "$(id -u):$(id -g)" "$WORK"
    fi
    if [[ "$(stat -c '%u' "$WORK")" != "$(id -u)" || ! -w "$WORK" ]]; then
        echo "No se puede escribir en $WORK incluso tras corregir su propietario." >&2
        exit 1
    fi
    INSTALLER_TMP="$(mktemp -d "${TMPDIR:-/tmp}/dylanos-installer-dist.XXXXXX")"
    INSTALLER_TMP="$(cd -- "$INSTALLER_TMP" && pwd -P)"
    # shellcheck disable=SC2317 # Invoked by EXIT trap.
    cleanup_installer_tmp() { rm -rf -- "$INSTALLER_TMP"; }
    trap cleanup_installer_tmp EXIT
    DYLANOS_INSTALLER_DIST="$INSTALLER_TMP/dist" bash "$ROOT/scripts/build-installer.sh"
    sudo unshare --mount --propagation private bash "$0" --inside \
        "--jobs=$BUILD_JOBS" "--installer-dist=$INSTALLER_TMP/dist" "--version=$VERSION" "$@"
fi
shift
PROFILE=development
RESUME=false
for arg in "$@"; do
    case "$arg" in
        --resume) RESUME=true ;;
        --minimal) PROFILE=default ;;
        --jobs=*) BUILD_JOBS="${arg#*=}" ;;
        --version=*) VERSION="${arg#*=}" ;;
        --installer-dist=*) INSTALLER_DIST="${arg#*=}" ;;
        *) echo "Uso: $0 [--resume] [--minimal] [--jobs=N]" >&2; exit 2 ;;
    esac
done
if [[ ! "$BUILD_JOBS" =~ ^[1-9][0-9]*$ ]]; then
    echo "DYLANOS_BUILD_JOBS debe ser un entero positivo." >&2
    exit 2
fi
if (( BUILD_JOBS > CPU_COUNT )); then
    echo "Ajustando los trabajos de compilación a los $CPU_COUNT núcleos disponibles." >&2
    BUILD_JOBS="$CPU_COUNT"
fi
echo "Compilación paralela: $BUILD_JOBS trabajo(s). Ajusta con DYLANOS_BUILD_JOBS=N."
CHROOT="$WORK/chroot"
mkdir -p "$WORK"
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
chroot "$CHROOT" /usr/bin/env BUILD_JOBS="$BUILD_JOBS" /bin/bash <<'CHROOT_SCRIPT'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=3 update
for setup in /tmp/dylanos-packages/*.setup-repos.sh; do
    if [[ -e "$setup" ]]; then bash "$setup"; fi
done
apt-get -o Acquire::Retries=3 update
# Resuelve los perfiles en una sola transacción APT para evitar repetir
# resolución de dependencias y configuración de dpkg por cada lista.
all_packages=/tmp/dylanos-packages/all-packages.txt
: > "$all_packages"
for list in /tmp/dylanos-packages/*.list; do
    [[ -f "$list" ]] && cat "$list" >> "$all_packages"
done
# Evita paquetes recomendados no solicitados; dependencias obligatorias siguen instalándose.
xargs -r -a "$all_packages" apt-get -o Acquire::Retries=3 install -y --no-install-recommends
sed -i 's/^# es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/; s/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=es_ES.UTF-8
systemctl enable sddm NetworkManager
passwd -l root
CHROOT_SCRIPT
if [[ -n "${INSTALLER_DIST:-}" ]]; then
    [[ -s "$INSTALLER_DIST/index.html" ]] || { echo "No existe el dist compilado del instalador: $INSTALLER_DIST" >&2; exit 1; }
    python3 "$ROOT/scripts/stage.py" --version "$VERSION" --installer-dist "$INSTALLER_DIST" "$CHROOT"
else
    python3 "$ROOT/scripts/stage.py" --version "$VERSION" "$CHROOT"
fi
mkdir -p "$CHROOT/tmp/dylanos-src"
for app in calculator dylanos-app-center; do
    mkdir -p "$CHROOT/tmp/dylanos-src/$app"
    cp -a "$ROOT/apps/$app/CMakeLists.txt" "$ROOT/apps/$app/src" "$ROOT/apps/$app/qml" "$CHROOT/tmp/dylanos-src/$app/"
    for extra in data icons dylanos-app-center.desktop; do
        if [[ -e "$ROOT/apps/$app/$extra" ]]; then cp -a "$ROOT/apps/$app/$extra" "$CHROOT/tmp/dylanos-src/$app/"; fi
    done
    chroot "$CHROOT" cmake -S "/tmp/dylanos-src/$app" -B "/tmp/dylanos-src/$app/build" -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
    chroot "$CHROOT" cmake --build "/tmp/dylanos-src/$app/build" --parallel "$BUILD_JOBS"
    chroot "$CHROOT" cmake --install "/tmp/dylanos-src/$app/build"
done
# DylanOS Explorer: gestor de archivos nativo (Qt6/QML).
mkdir -p "$CHROOT/tmp/dylanos-src/dylanos-explorer"
cp -a "$ROOT/apps/dylanos-explorer/." "$CHROOT/tmp/dylanos-src/dylanos-explorer/"
chroot "$CHROOT" cmake -S /tmp/dylanos-src/dylanos-explorer -B /tmp/dylanos-src/dylanos-explorer/build -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
chroot "$CHROOT" cmake --build /tmp/dylanos-src/dylanos-explorer/build --parallel "$BUILD_JOBS"
chroot "$CHROOT" ctest --test-dir /tmp/dylanos-src/dylanos-explorer/build --output-on-failure
chroot "$CHROOT" cmake --install /tmp/dylanos-src/dylanos-explorer/build
# DylanOS Configuration: única app de configuración (Qt6/QML sobre módulos KCM).
mkdir -p "$CHROOT/tmp/dylanos-src/dylanos-configuration"
cp -a "$ROOT/apps/dylanos-configuration/." "$CHROOT/tmp/dylanos-src/dylanos-configuration/"
# El logo oficial se incrusta en el binario (qrc:/assets/logo.png).
cp -a "$ROOT/branding/logo.png" "$CHROOT/tmp/dylanos-src/dylanos-configuration/assets/logo.png"
chroot "$CHROOT" cmake -S /tmp/dylanos-src/dylanos-configuration -B /tmp/dylanos-src/dylanos-configuration/build -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
chroot "$CHROOT" cmake --build /tmp/dylanos-src/dylanos-configuration/build --parallel "$BUILD_JOBS"
chroot "$CHROOT" cmake --install /tmp/dylanos-src/dylanos-configuration/build
# DylanOS Store: fork nativo de Discover (libdiscover + UI del prototipo).
mkdir -p "$CHROOT/tmp/dylanos-src/dylanos-store" "$CHROOT/tmp/dylanos-src/catalog"
cp -a "$ROOT/apps/dylanos-store/src/." "$CHROOT/tmp/dylanos-src/dylanos-store/"
cp -a "$ROOT/apps/dylanos-store/catalog/store.db" "$CHROOT/tmp/dylanos-src/catalog/"
chroot "$CHROOT" cmake -S /tmp/dylanos-src/dylanos-store -B /tmp/dylanos-src/dylanos-store/build -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
chroot "$CHROOT" cmake --build /tmp/dylanos-src/dylanos-store/build --parallel "$BUILD_JOBS"
chroot "$CHROOT" ctest --test-dir /tmp/dylanos-src/dylanos-store/build --output-on-failure
chroot "$CHROOT" cmake --install /tmp/dylanos-src/dylanos-store/build
chroot "$CHROOT" /bin/bash <<'CHROOT_SCRIPT'
set -euo pipefail
plymouth-set-default-theme dylanos
update-initramfs -u -k all
# Herramienta de compilación de la caché: se instala solo durante el build.
apt-get -y install --no-install-recommends desktop-file-utils
update-desktop-database /usr/share/applications
apt-get -y purge desktop-file-utils
# Los -dev exclusivos de la DylanOS Store no se envían en el ISO.
apt-get -y purge libflatpak-dev libostree-dev libappstreamqt-dev libpackagekitqt6-dev \
    qcoro-qt6-dev kirigami-addons-dev libkirigami-dev libkf6xmlgui-dev \
    libkf6idletime-dev libkf6statusnotifieritem-dev libkf6notifications-dev \
    libkf6crash-dev libkf6dbusaddons-dev libkf6archive-dev qt6-svg-dev \
    libkf6iconthemes-dev libkf6auth-dev
# Un solo explorador de archivos (DylanOS Explorer) y una sola calculadora
# (dylanos-calculator): dolphin y kcalc entran como dependencias del
# metapaquete kde-plasma-desktop y se retiran del sistema final. El motor KIO
# del Explorer (libkf6kio*) y el resto de la pila Plasma permanecen intactos.
# DylanOS Console (Kitty) es la única terminal: konsole entra a veces como
# recomendación de kde-plasma-desktop y se retira del sistema final.
apt-get -y purge dolphin dolphin-plugins kcalc konsole
# Retira únicamente dependencias automáticas que APT confirme como huérfanas.
apt-get -y autoremove --purge
apt-get clean
# Los índices se regeneran con apt-get update; no hacen falta para arrancar.
rm -rf /var/lib/apt/lists/*
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
