#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO="$ROOT/DylanOS-1.0-amd64.iso"

echo "================================="
echo "        DylanOS TEST"
echo "================================="

if [ ! -f "$ISO" ]; then
    echo "ERROR: No existe la ISO."
    exit 1
fi

echo "[OK] ISO encontrada"

echo
echo "Tamaño:"
ls -lh "$ISO"

echo
echo "Tipo:"
file "$ISO"

echo
echo "Integridad:"
sha256sum "$ISO"

echo
echo "TEST COMPLETADO"
