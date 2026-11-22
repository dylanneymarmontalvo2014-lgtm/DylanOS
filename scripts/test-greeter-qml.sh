#!/bin/bash
# Test Greeter de SDDM sobre el tema QML clásico (`Main.qml`).
#
# Ejecuta `sddm-greeter --test-mode` con una copia del tema y el fondo local,
# y activa la captura opt-in de theme.conf. Un tema sano no debe mostrar
# ReferenceError, TypeError ni «Fallback to embedded theme».
#
# Uso: scripts/test-greeter-qml.sh [salida]
# Requiere ejecutarse dentro del chroot (Qt 6.8) o en un sistema con
# sddm-greeter-qt6 instalado.
set -u
ROOT=$(cd "${0%/*}/.." && pwd)
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
export HOME=${HOME:-/tmp}
export QT_QPA_PLATFORM=offscreen
export QT_QUICK_BACKEND=software

salida=${1:-$ROOT/artifacts/sddm-qa}
tema=$ROOT/themes/sddm/DylanOS-Crimson
fondo=$ROOT/branding/wallpapers/dylanos-default.png
greeter=${GREETER:-/usr/bin/sddm-greeter-qt6}

mkdir -p "$salida"
rm -rf /tmp/tema-qml
# `cp -a` conservaría el symlink de logo.png, que apunta fuera del tema y se
# rompe al copiarlo (stage.py lo resuelve, así que en el ISO el PNG es real).
cp -aL "$tema" /tmp/tema-qml
sed -i "s|^background=.*|background=$fondo|" /tmp/tema-qml/theme.conf
sed -i "s|^screenshot=.*|screenshot=$salida/greeter-qml.png|" /tmp/tema-qml/theme.conf

salida_greeter=$(timeout 25 "$greeter" --test-mode --theme /tmp/tema-qml 2>&1)
printf '%s\n' "$salida_greeter" | grep -viE '^$' | tail -12

echo "--- diagnóstico:"
if printf '%s\n' "$salida_greeter" | grep -qiE 'ReferenceError|TypeError|Fallback to embedded theme'; then
    echo "FALLO: el tema produjo errores de QML"
    exit 1
fi
echo "OK: sin errores de QML"

echo "--- captura:"
if [ -s "$salida/greeter-qml.png" ]; then
    echo "OK: $salida/greeter-qml.png ($(stat -c%s "$salida/greeter-qml.png") bytes)"
else
    echo "SIN CAPTURA (la plataforma offscreen puede no permitir grabToImage)"
    exit 1
fi
