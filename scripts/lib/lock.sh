#!/usr/bin/env bash
# Lock compartido entre build e ISO fuera del checkout. Se abre en modo lectura
# para que un archivo creado originalmente por la fase root siga siendo usable.
dylanos_acquire_build_lock() {
    local repository_root="$1"
    local busy_message="${2:-Ya hay una construcción en marcha.}"
    local lock_key lock_file

    lock_key="$(printf '%s' "$repository_root" | sha256sum)"
    lock_key="${lock_key%% *}"
    lock_file="${TMPDIR:-/tmp}/dylanos-build-${lock_key:0:24}.lock"

    if [[ -L "$lock_file" ]]; then
        echo "Ruta de lock insegura (enlace simbólico): $lock_file" >&2
        return 1
    fi
    if [[ ! -e "$lock_file" ]]; then
        (umask 022; set -o noclobber; : > "$lock_file") 2>/dev/null || true
    fi
    if [[ -L "$lock_file" || ! -f "$lock_file" ]]; then
        echo "No se pudo preparar el archivo de lock: $lock_file" >&2
        return 1
    fi
    if ! exec 9< "$lock_file"; then
        echo "No se pudo abrir el archivo de lock: $lock_file" >&2
        return 1
    fi
    if ! flock -n 9; then
        echo "$busy_message" >&2
        return 1
    fi
}
