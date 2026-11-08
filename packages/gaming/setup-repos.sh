#!/usr/bin/env bash
# Prepara el chroot del perfil gaming: arquitectura i386 para Steam/Wine.
# Lo ejecuta build.sh DENTRO del chroot como root. Idempotente.
# No añade repositorios de terceros: Steam entra por contrib Debian.
set -euo pipefail

echo "[setup-repos/gaming] Habilitando arquitectura i386 para Steam y Wine..."

if dpkg --print-foreign-architectures | grep -qx i386; then
    echo "[setup-repos/gaming] i386 ya estaba habilitada."
else
    dpkg --add-architecture i386
fi

echo "[setup-repos/gaming] Arquitectura i386 lista. Ejecutar 'apt update' después."
