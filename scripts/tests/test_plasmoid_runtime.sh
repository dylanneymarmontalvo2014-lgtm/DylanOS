#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHROOT="${1:-$ROOT/work/chroot}"

if [[ ! -x "$CHROOT/usr/bin/plasmawindowed" ]]; then
    echo "Falta plasmawindowed en el chroot: $CHROOT" >&2
    exit 1
fi

if (( EUID == 0 )); then
    elevate=()
else
    elevate=(sudo -n)
fi

check_applet() {
    local applet="$1"
    local source="$ROOT/apps/$applet"
    local output
    local status

    output="$(mktemp "${TMPDIR:-/tmp}/dylanos-${applet//./-}.XXXXXX.log")"
    set +e
    # Los parámetros posicionales se expanden en el bash aislado.
    # shellcheck disable=SC2016
    "${elevate[@]}" unshare --mount --propagation private bash -c '
        set -euo pipefail
        mount --rbind /dev "$1/dev"
        mount --make-rslave "$1/dev"
        mount -t proc proc "$1/proc"
        mount --bind "$2" "$1/usr/share/plasma/plasmoids/$3"
        QT_QPA_PLATFORM=offscreen timeout 6 chroot "$1" \
            /usr/bin/dbus-run-session -- /usr/bin/plasmawindowed "$3"
    ' audit "$CHROOT" "$source" "$applet" >"$output" 2>&1
    status=$?
    set -e

    if [[ $status -ne 0 && $status -ne 124 ]]; then
        cat "$output" >&2
        rm -f -- "$output"
        echo "$applet terminó con estado $status" >&2
        return 1
    fi

    if grep -E 'error when loading applet|QQmlComponent: Component is not ready|ReferenceError:|TypeError:|not a type|Unable to assign' "$output"; then
        rm -f -- "$output"
        echo "$applet produjo errores QML" >&2
        return 1
    fi

    rm -f -- "$output"
    echo "OK: $applet carga sin errores QML"
}

check_applet com.dylanos.activeapp
check_applet com.dylanos.dock
