#!/usr/bin/env bash
# Build the installer frontend required by scripts/stage.py.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/installer/dylanos-installer"
for tool in node npm; do
    command -v "$tool" >/dev/null 2>&1 || { printf 'Missing dependency: %s (required to build the installer frontend).\n' "$tool" >&2; exit 1; }
done
node -e '
const [major, minor] = process.versions.node.split(".").map(Number);
const supported = major >= 24 || (major === 22 && minor >= 12) || (major === 20 && minor >= 19);
if (!supported) { console.error("Unsupported Node.js " + process.versions.node + "; Vite requires 20.19+, 22.12+, or 24+."); process.exit(1); }
'
BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dylanos-installer-build.XXXXXX")"
cleanup() { rm -rf -- "$BUILD_ROOT"; }
trap cleanup EXIT
OUTPUT_DIR="${DYLANOS_INSTALLER_DIST:-$APP/dist}"
mkdir -p "$OUTPUT_DIR"
# Build from an isolated copy: npm ci deletes/recreates node_modules, which may
# contain root-owned links after older sudo-based builds in the user checkout.
tar --exclude='./node_modules' --exclude='./dist' --exclude='./.git' -cf - -C "$APP" . | tar -xf - -C "$BUILD_ROOT"
cd "$BUILD_ROOT"
npm ci --no-audit --no-fund
npm run build -- --outDir "$OUTPUT_DIR"
if [[ ! -s "$OUTPUT_DIR/index.html" ]]; then
    printf 'Installer build did not produce a non-empty dist/index.html.\n' >&2
    exit 1
fi
printf 'Installer frontend built in isolation: %s\n' "$OUTPUT_DIR/index.html"
