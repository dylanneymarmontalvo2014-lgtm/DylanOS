#!/usr/bin/env bash
# Agrega repositorios apt externos del grupo "development".
# Lo ejecuta build.sh DENTRO del chroot como root.
# Debe ser idempotente: puede ejecutarse varias veces sin romper nada.
set -euo pipefail

VSCODIUM_KEY_URL="https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg"
VSCODIUM_KEYRING="/usr/share/keyrings/vscodium-archive-keyring.asc"
VSCODIUM_SOURCES="/etc/apt/sources.list.d/vscodium.sources"

echo "[setup-repos/development] Agregando repo apt de VSCodium..."

# Prerrequisitos (no están garantizados en un chroot minbase)
apt-get install -y --no-install-recommends ca-certificates wget

# Llave GPG del repo (armadura ASCII, no requiere gpg --dearmor)
wget -qO "$VSCODIUM_KEYRING" "$VSCODIUM_KEY_URL"

if [ ! -s "$VSCODIUM_KEYRING" ]; then
    echo "ERROR: la llave GPG de VSCodium se descargó vacía" >&2
    exit 1
fi

# Entrada del repo en formato deb822 (Debian trixie+)
cat > "$VSCODIUM_SOURCES" <<EOF
Types: deb
Architectures: amd64 arm64
URIs: https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs
Suites: vscodium
Components: main
Signed-By: $VSCODIUM_KEYRING
EOF

echo "[setup-repos/development] Repo de VSCodium agregado. Ejecutar 'apt update' después."
