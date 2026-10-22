#!/usr/bin/env bash
# Instala las herramientas de construcción, QA y prueba de DylanOS.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VENV="${DYLANOS_VENV:-$ROOT/.venv}"
ASSUME_YES=false
NODE_KEY_URL="https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"

usage() {
    cat <<'HELP'
Uso: bash init.sh [--yes]

Prepara las dependencias de DylanOS en Debian/Ubuntu amd64. Sin opciones,
muestra los paquetes y pide confirmación antes de instalar paquetes o configurar
el repositorio NodeSource. Crea o actualiza el entorno Python .venv.

  --yes   No pregunta (para automatización; úsalo solo cuando ya aprobaste los cambios).
  --help  Muestra esta ayuda.
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

if [[ ! -r /etc/os-release ]]; then
    echo 'No se pudo identificar la distribución. Se requiere Debian o Ubuntu.' >&2
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-} ${ID_LIKE:-}" in
    *debian*|*ubuntu*) ;;
    *) echo "Distribución no compatible: ${PRETTY_NAME:-desconocida}. Se requiere Debian/Ubuntu." >&2; exit 1 ;;
esac

if ! command -v dpkg >/dev/null 2>&1 || [[ "$(dpkg --print-architecture)" != amd64 ]]; then
    echo 'DylanOS solo prepara dependencias para Debian/Ubuntu amd64.' >&2
    exit 1
fi
if ! command -v apt-get >/dev/null 2>&1; then
    echo 'No se encontró apt-get.' >&2
    exit 1
fi
if (( EUID != 0 )) && ! command -v sudo >/dev/null 2>&1; then
    echo 'Necesitas ejecutar como root o tener sudo instalado.' >&2
    exit 1
fi
if [[ ! -f "$ROOT/apps/workspace/requirements-dev.txt" ]]; then
    echo "No se encontró $ROOT/apps/workspace/requirements-dev.txt; ejecuta init.sh desde un checkout completo." >&2
    exit 1
fi
if [[ "$VENV" != /* ]]; then VENV="$ROOT/$VENV"; fi

APT_PACKAGES=(
    build-essential ca-certificates curl debootstrap desktop-file-utils dosfstools
    gnupg gir1.2-gtk-3.0 gir1.2-gtk-4.0 grub-common grub-efi-amd64-bin
    grub-pc-bin libdbus-1-3 libegl1 libfontconfig1 libfreetype6 libopengl0
    libx11-6 libx11-xcb1 libxcb-cursor0 libxcb-icccm4 libxcb-keysyms1
    libxcb-randr0 libxcb-render-util0 libxcb-shape0 libxcb-xfixes0 libxcb-xkb1
    libxkbcommon0 libxkbcommon-x11-0 make mtools nodejs python3 python3-gi
    python3-pip python3-venv qemu-system-x86 qemu-utils shellcheck sudo
    squashfs-tools util-linux xorriso
)
case "${ID:-}:${VERSION_ID:-}" in
    ubuntu:2[4-9].*|ubuntu:3[0-9].*|debian:1[3-9]|debian:1[3-9].*)
        APT_PACKAGES+=(libglib2.0-0t64)
        ;;
    *)
        APT_PACKAGES+=(libglib2.0-0)
        ;;
esac

printf '%s\n' 'init.sh preparará DylanOS con:'
printf '  - %s\n' "${APT_PACKAGES[@]}"
printf '  - Repositorio oficial NodeSource 22.x y su clave de firma\n'
printf '  - Entorno Python: %s (creará/actualizará dependencias de requirements-dev.txt)\n' "$VENV"
printf '%s\n' 'Se actualizará el índice de apt y se instalarán los paquetes indicados.'
if [[ "$ASSUME_YES" != true ]]; then
    if ! read -r -p '¿Quieres instalar y configurar estas dependencias ahora? [s/N] ' answer; then
        echo 'No se recibió confirmación; no se hicieron cambios.'
        exit 0
    fi
    case "$answer" in
        s|S|si|Si|SI|sí|Sí|SÍ|y|Y|yes|YES) ;;
        *) echo 'Cancelado; no se hicieron cambios.'; exit 0 ;;
    esac
fi

run_as_root() {
    if (( EUID == 0 )); then
        "$@"
    else
        sudo "$@"
    fi
}

run_as_root apt-get update
run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg

key_tmp="$(mktemp)"
source_tmp="$(mktemp)"
trap 'rm -f "$key_tmp" "$source_tmp"' EXIT
curl -fsSL "$NODE_KEY_URL" | gpg --dearmor > "$key_tmp"
run_as_root install -d -m 0755 /etc/apt/keyrings
run_as_root install -m 0644 "$key_tmp" /etc/apt/keyrings/nodesource.gpg
arch="$(dpkg --print-architecture)"
printf 'deb [arch=%s signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main\n' "$arch" > "$source_tmp"
run_as_root install -m 0644 "$source_tmp" /etc/apt/sources.list.d/nodesource.list

run_as_root apt-get update
run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    "${APT_PACKAGES[@]}"

if ! node -e 'const [major, minor] = process.versions.node.split(".").map(Number); if (!(major >= 24 || (major === 22 && minor >= 12) || (major === 20 && minor >= 19))) process.exit(1);'; then
    echo "Node.js $(node --version) no cumple el mínimo de build-installer.sh." >&2
    exit 1
fi

mkdir -p "$(dirname -- "$VENV")"
# El acceso a los paquetes del sistema permite usar python3-gi durante la QA GTK.
python3 -m venv --system-site-packages "$VENV"
"$VENV/bin/python" -m pip install --upgrade pip
"$VENV/bin/python" -m pip install --requirement "$ROOT/apps/workspace/requirements-dev.txt"
printf '\nDependencias listas. Para las comprobaciones usa:\n  make check PYTHON=%s/bin/python\n' "$VENV"
