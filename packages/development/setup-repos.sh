#!/usr/bin/env bash
# Agrega repositorios apt externos del grupo "development".
# Lo ejecuta build.sh DENTRO del chroot como root.
# Debe ser idempotente: puede ejecutarse varias veces sin romper nada.
set -euo pipefail

# Visual Studio Code (paquete oficial `code` de Microsoft). El binario que
# distribuye Microsoft se rige por su propia licencia (el código fuente
# "Code - OSS" es MIT); documentado en docs/licenses/assets.md.
VSCODE_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
VSCODE_KEYRING="/usr/share/keyrings/microsoft-archive-keyring.gpg"
VSCODE_SOURCES="/etc/apt/sources.list.d/vscode.sources"
# Restos del repo de VSCodium de builds anteriores (chroot reutilizable):
# VSCodium fue sustituido por Visual Studio Code y no debe volver a entrar.
VSCODIUM_KEYRING="/usr/share/keyrings/vscodium-archive-keyring.asc"
VSCODIUM_SOURCES="/etc/apt/sources.list.d/vscodium.sources"

echo "[setup-repos/development] Agregando repo apt oficial de Visual Studio Code..."

# Prerrequisitos (no están garantizados en un chroot minbase)
apt-get install -y --no-install-recommends ca-certificates wget

# Llave GPG del repo (armadura ASCII, no requiere gpg --dearmor)
wget -qO "$VSCODE_KEYRING" "$VSCODE_KEY_URL"

if [ ! -s "$VSCODE_KEYRING" ]; then
    echo "ERROR: la llave GPG de Microsoft se descargó vacía" >&2
    exit 1
fi

# Entrada del repo en formato deb822 (Debian trixie+)
cat > "$VSCODE_SOURCES" <<EOF
Types: deb
Architectures: amd64 arm64
URIs: https://packages.microsoft.com/repos/vscode
Suites: stable
Components: main
Signed-By: $VSCODE_KEYRING
EOF

rm -f "$VSCODIUM_KEYRING" "$VSCODIUM_SOURCES"

echo "[setup-repos/development] Repo de Visual Studio Code agregado. Ejecutar 'apt update' después."
