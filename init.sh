#!/usr/bin/env bash
# Prepara dependencias nativas en Debian/Ubuntu o usa el builder Docker en otros Linux.
# shellcheck disable=SC1091
# shellcheck source=scripts/build-host.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/scripts/build-host.sh"
# shellcheck disable=SC1091
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/scripts/docker-compose.sh"
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ASSUME_YES=false
NODE_KEY_URL="https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
INIT_TMP_FILES=()
cleanup_init_tmp_files() {
    if ((${#INIT_TMP_FILES[@]})); then
        rm -f -- "${INIT_TMP_FILES[@]}"
    fi
}
trap cleanup_init_tmp_files EXIT

usage() {
    cat <<'HELP'
Uso: bash init.sh [--yes]

- Debian/Ubuntu amd64: ofrece instalar dependencias del host y preparar .venv.
- Otros Linux amd64: usa el builder Docker; si falta Docker/Compose, intenta
  instalarlos automáticamente en Arch, Fedora, openSUSE y Alpine.

Sin opciones pide confirmación antes de instalar paquetes, iniciar servicios o
construir la imagen. --yes omite la pregunta (solo para automatización aprobada).
HELP
}

while (($#)); do
    case "$1" in
        --yes) ASSUME_YES=true ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Opción desconocida: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ "$(uname -s)" != Linux || ! -r /etc/os-release ]]; then
    echo 'init.sh requiere Linux; para macOS/Windows instala y ejecuta Docker Desktop por separado.' >&2
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
HOST_ARCH="$(uname -m)"
if [[ "$HOST_ARCH" != x86_64 && "$HOST_ARCH" != amd64 ]]; then
    echo 'DylanOS solo prepara dependencias para Linux amd64.' >&2
    exit 1
fi

HOST_FAMILY="$(detect_host_family "${ID:-}" "${ID_LIKE:-}")"
NATIVE=false
if [[ "$HOST_FAMILY" == debian ]]; then NATIVE=true; fi

run_as_root() {
    if (( EUID == 0 )); then
        "$@"
    else
        sudo "$@"
    fi
}
require_root_access() {
    if (( EUID != 0 )) && ! command -v sudo >/dev/null 2>&1; then
        echo 'Esta acción necesita root o sudo.' >&2
        exit 1
    fi
}

confirm_changes() {
    if [[ "$ASSUME_YES" == true ]]; then return 0; fi
    local answer
    if ! read -r -p '¿Quieres continuar con estos cambios? [s/N] ' answer; then
        echo 'No se recibió confirmación; no se hicieron cambios.'
        exit 0
    fi
    case "$answer" in
        s|S|si|Si|SI|sí|Sí|SÍ|y|Y|yes|YES) ;;
        *) echo 'Cancelado; no se hicieron cambios.'; exit 0 ;;
    esac
}

install_native_dependencies() {
    local venv="${DYLANOS_VENV:-$ROOT/.venv}"
    local arch
    local apt_packages=(
        bash-completion build-essential ca-certificates curl debootstrap desktop-file-utils dosfstools
        gnupg gir1.2-gtk-3.0 gir1.2-gtk-4.0 grub-common grub-efi-amd64-bin
        grub-pc-bin libdbus-1-3 libegl1 libfontconfig1 libfreetype6 libgl1 libopengl0
        libx11-6 libx11-xcb1 libxcb-cursor0 libxcb-icccm4 libxcb-keysyms1
        libxcb-randr0 libxcb-render-util0 libxcb-shape0 libxcb-xfixes0 libxcb-xkb1
        libxkbcommon0 libxkbcommon-x11-0 make mtools nodejs python3 python3-gi
        python3-pip python3-venv qemu-system-x86 qemu-utils shellcheck sudo
        squashfs-tools util-linux xorriso
    )

    if [[ ! -f "$ROOT/apps/workspace/requirements-dev.txt" ]]; then
        echo "No se encontró $ROOT/apps/workspace/requirements-dev.txt; ejecuta init.sh desde un checkout completo." >&2
        exit 1
    fi
    if ! command -v apt-get >/dev/null 2>&1; then
        echo 'No se encontró apt-get.' >&2
        exit 1
    fi
    if ! command -v dpkg >/dev/null 2>&1; then
        echo 'No se encontró dpkg para el modo Debian/Ubuntu.' >&2
        exit 1
    fi
    if (( EUID != 0 )) && ! command -v sudo >/dev/null 2>&1; then
        echo 'Necesitas ejecutar como root o tener sudo instalado.' >&2
        exit 1
    fi
    case "${ID:-}:${VERSION_ID:-}" in
        ubuntu:2[4-9].*|ubuntu:3[0-9].*|debian:1[3-9]|debian:1[3-9].*)
            apt_packages+=(libglib2.0-0t64)
            ;;
        *) apt_packages+=(libglib2.0-0) ;;
    esac
    if [[ "$venv" != /* ]]; then venv="$ROOT/$venv"; fi

    printf '%s\n' 'El modo nativo instalará estas dependencias del sistema:'
    printf '  - %s\n' "${apt_packages[@]}"
    printf '%s\n' 'También configurará NodeSource 22.x y creará/actualizará el entorno Python.'
    printf '  - Entorno: %s\n' "$venv"
    confirm_changes

    run_as_root apt-get update
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg

    local key_tmp source_tmp
    key_tmp="$(mktemp)"
    source_tmp="$(mktemp)"
    INIT_TMP_FILES+=("$key_tmp" "$source_tmp")
    curl -fsSL "$NODE_KEY_URL" | gpg --dearmor > "$key_tmp"
    run_as_root install -d -m 0755 /etc/apt/keyrings
    run_as_root install -m 0644 "$key_tmp" /etc/apt/keyrings/nodesource.gpg
    arch="$(dpkg --print-architecture)"
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main\n' "$arch" > "$source_tmp"
    run_as_root install -m 0644 "$source_tmp" /etc/apt/sources.list.d/nodesource.list

    run_as_root apt-get update
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        "${apt_packages[@]}"

    if ! node -e 'const [major, minor] = process.versions.node.split(".").map(Number); if (!(major >= 24 || (major === 22 && minor >= 12) || (major === 20 && minor >= 19))) process.exit(1);'; then
        echo "Node.js $(node --version) no cumple el mínimo de build-installer.sh." >&2
        exit 1
    fi

    mkdir -p "$(dirname -- "$venv")"
    # python3-gi viene de apt; system-site-packages permite usarlo en la QA GTK.
    python3 -m venv --system-site-packages "$venv"
    "$venv/bin/python" -m pip install --upgrade pip
    "$venv/bin/python" -m pip install --requirement "$ROOT/apps/workspace/requirements-dev.txt"
    printf '\nDependencias listas. Para las comprobaciones usa:\n  make check PYTHON=%s/bin/python\n' "$venv"
}

docker_install_supported() {
    host_family_supports_docker_install "$HOST_FAMILY"
}

install_docker() {
    require_root_access
    case "$HOST_FAMILY" in
        arch)
            command -v pacman >/dev/null 2>&1 || { echo 'No se encontró pacman para instalar Docker.' >&2; exit 1; }
            run_as_root pacman -S --needed --noconfirm docker docker-compose
            ;;
        fedora|rhel)
            command -v dnf >/dev/null 2>&1 || { echo 'No se encontró dnf para instalar Docker.' >&2; exit 1; }
            if ! dnf config-manager --help >/dev/null 2>&1; then
                if [[ "$HOST_FAMILY" == fedora ]]; then
                    if ! run_as_root dnf install -y dnf5-plugins; then
                        run_as_root dnf install -y dnf-plugins-core
                    fi
                else
                    run_as_root dnf install -y dnf-plugins-core
                fi
            fi
            if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
                local repo_family=fedora
                if [[ "$HOST_FAMILY" == rhel ]]; then repo_family=centos; fi
                if dnf config-manager addrepo --help >/dev/null 2>&1; then
                    run_as_root dnf config-manager addrepo --from-repofile "https://download.docker.com/linux/${repo_family}/docker-ce.repo"
                else
                    run_as_root dnf config-manager --add-repo "https://download.docker.com/linux/${repo_family}/docker-ce.repo"
                fi
            fi
            run_as_root dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        opensuse)
            command -v zypper >/dev/null 2>&1 || { echo 'No se encontró zypper para instalar Docker.' >&2; exit 1; }
            run_as_root zypper --non-interactive install docker docker-compose
            ;;
        alpine)
            command -v apk >/dev/null 2>&1 || { echo 'No se encontró apk para instalar Docker.' >&2; exit 1; }
            run_as_root apk add docker docker-cli-compose
            ;;
        *)
            echo "No puedo instalar Docker automáticamente en ${PRETTY_NAME:-esta distribución}; instala Docker Engine y Compose v2 con el gestor oficial de tu distro." >&2
            exit 1
            ;;
    esac
}

start_docker_service() {
    if docker info >/dev/null 2>&1; then return 0; fi
    require_root_access
    if command -v systemctl >/dev/null 2>&1; then
        run_as_root systemctl enable --now docker
    elif command -v rc-service >/dev/null 2>&1; then
        run_as_root rc-update add docker default
        run_as_root rc-service docker start
    else
        echo 'Docker no responde y no encontré systemd/OpenRC para iniciarlo automáticamente.' >&2
        exit 1
    fi
}

run_docker() {
    if docker info >/dev/null 2>&1; then
        docker "$@"
    elif (( EUID != 0 )) && command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
        sudo docker "$@"
    else
        echo 'No pude conectar con Docker ni como usuario ni con sudo.' >&2
        exit 1
    fi
}

run_compose() {
    local kind
    kind="$(dylanos_docker_compose_kind)" || {
        echo 'No encontré Docker Compose v2: instala el plugin `docker compose` o el binario `docker-compose` v2.' >&2
        exit 1
    }
    if [[ "$kind" == plugin ]]; then
        run_docker compose "$@"
    elif docker info >/dev/null 2>&1; then
        docker-compose "$@"
    elif (( EUID != 0 )) && command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
        sudo docker-compose "$@"
    else
        echo 'No pude conectar con Docker ni como usuario ni con sudo.' >&2
        exit 1
    fi
}

prepare_docker_builder() {
    local missing=false
    if ! command -v docker >/dev/null 2>&1 || ! dylanos_docker_compose_available; then missing=true; fi
    if [[ "$missing" == true ]] && ! docker_install_supported; then
        echo "No hay Docker Compose v2 y no puedo instalarlo automáticamente en ${PRETTY_NAME:-esta distro}." >&2
        echo 'Instala Docker Engine y Compose v2 con el método oficial de tu distribución y vuelve a ejecutar init.sh.' >&2
        exit 1
    fi
    if [[ ! -f "$ROOT/compose.yaml" || ! -f "$ROOT/Dockerfile" ]]; then
        echo 'No encontré compose.yaml/Dockerfile; ejecuta init.sh desde la raíz del repositorio.' >&2
        exit 1
    fi

    printf '%s\n' "${PRETTY_NAME:-Este Linux} no usará dependencias Debian nativas: se preparará el builder Docker."
    if [[ "$missing" == true ]]; then
        echo 'Docker/Compose v2 no está listo; init.sh lo instalará automáticamente para esta distribución.'
    elif ! docker info >/dev/null 2>&1; then
        echo 'El daemon Docker no responde; init.sh intentará habilitarlo e iniciarlo.'
    else
        echo 'Docker y Compose v2 ya están disponibles.'
    fi
    echo 'Al final construirá la imagen local dylanos-builder:local.'
    confirm_changes

    if [[ "$missing" == true ]]; then install_docker; fi
    start_docker_service
    if ! dylanos_docker_compose_available; then
        echo "Docker Compose v2 no quedó disponible (plugin 'docker compose' ni ejecutable 'docker-compose')." >&2
        exit 1
    fi
    (cd "$ROOT" && run_compose build builder)
    echo "Builder listo. Desde la raíz del repo ejecuta 'docker compose run --rm builder make check' o 'docker-compose run --rm builder make check' según el modo disponible."
}

if [[ "$NATIVE" == true ]]; then
    install_native_dependencies
else
    prepare_docker_builder
fi
