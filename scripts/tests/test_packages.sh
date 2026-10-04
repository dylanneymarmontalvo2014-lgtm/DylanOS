#!/usr/bin/env bash
# Tests del mecanismo de paquetes de DylanOS.
# Cubre: scripts/lib/packages.sh (parser de listas) y las listas reales en packages/.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/scripts/lib/packages.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }

fail() {
    echo "FAIL: $1"
    FAIL=$((FAIL + 1))
}

# assert_eq <descripción> <esperado> <obtenido>
assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        pass
    else
        fail "$desc — esperado [$expected], obtenido [$actual]"
    fi
}

# assert_contains_line <descripción> <texto multilinea> <línea esperada>
assert_contains_line() {
    local desc="$1" haystack="$2" needle="$3"
    if printf '%s\n' "$haystack" | grep -qx -- "$needle"; then
        pass
    else
        fail "$desc — [$needle] no encontrado"
    fi
}

# assert_command_fails <descripción> <comando...>
assert_command_fails() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        fail "$desc — se esperaba fallo, terminó OK"
    else
        pass
    fi
}

if [ ! -f "$LIB" ]; then
    echo "FATAL: no existe $LIB"
    exit 1
fi
# shellcheck source=scripts/lib/packages.sh
. "$LIB"

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

# ------------------------------------------------------------------
# parse_package_list
# ------------------------------------------------------------------

# Ignora comentarios y líneas vacías
printf '%s\n' '# sistema base' '' 'git' > "$FIX/comentarios.list"
out="$(parse_package_list "$FIX/comentarios.list")"
assert_eq "ignora comentarios y líneas vacías" "git" "$out"

# Recorta espacios y tabuladores alrededor del nombre
printf '%s\n' '   codium	' > "$FIX/espacios.list"
out="$(parse_package_list "$FIX/espacios.list")"
assert_eq "recorta espacios alrededor del nombre" "codium" "$out"

# Elimina retornos de carro (listas con finales CRLF)
printf 'git\r\ncodium\r\n' > "$FIX/crlf.list"
out="$(parse_package_list "$FIX/crlf.list")"
assert_eq "elimina retornos de carro (CRLF)" "git
codium" "$out"

# Recorta comentarios al final de línea
printf '%s\n' 'build-essential # toolchain básico' > "$FIX/inline.list"
out="$(parse_package_list "$FIX/inline.list")"
assert_eq "recorta comentarios en línea" "build-essential" "$out"

# Conserva el orden del archivo
printf '%s\n' 'b' 'a' > "$FIX/orden.list"
out="$(parse_package_list "$FIX/orden.list")"
assert_eq "conserva el orden del archivo" "b
a" "$out"

# Falla si la lista no existe (fail fast)
assert_command_fails "falla si la lista no existe" \
    parse_package_list "$FIX/no-existe.list"

# ------------------------------------------------------------------
# Listas reales del repositorio
# ------------------------------------------------------------------

DEFAULT_LIST="$ROOT/packages/default/packages.list"
DEV_LIST="$ROOT/packages/development/packages.list"

assert_eq "la lista default existe" "si" "$([ -f "$DEFAULT_LIST" ] && echo si || echo no)"
assert_eq "la lista development existe" "si" "$([ -f "$DEV_LIST" ] && echo si || echo no)"

default_pkgs="$(parse_package_list "$DEFAULT_LIST" 2>/dev/null || true)"
dev_pkgs="$(parse_package_list "$DEV_LIST" 2>/dev/null || true)"

# Paquetes del sistema base migrados del build.sh original
for p in linux-image-amd64 systemd-sysv kde-plasma-desktop sddm calamares \
    sudo network-manager dolphin konsole; do
    assert_contains_line "default contiene $p" "$default_pkgs" "$p"
done

# Apps declaradas en configs/default-apps.conf deben instalarse por defecto
conf_apps="$(grep -vE '^\[|^$|^[[:space:]]*[#;]' "$ROOT/configs/default-apps.conf")"
while IFS= read -r app; do
    [ -n "$app" ] || continue
    assert_contains_line "default-apps.conf: $app está en la lista default" \
        "$default_pkgs" "$app"
done <<< "$conf_apps"

# Herramientas de desarrollo comprometidas en el diseño
for p in git build-essential curl wget openssh-client python3 python3-pip \
    nodejs npm codium; do
    assert_contains_line "development contiene $p" "$dev_pkgs" "$p"
done

# ------------------------------------------------------------------
echo
echo "Pasaron: $PASS  Fallaron: $FAIL"
[ "$FAIL" -eq 0 ]
