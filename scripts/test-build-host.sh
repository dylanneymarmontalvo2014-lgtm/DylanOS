#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/build-host.sh
. "$ROOT/scripts/build-host.sh"

assert_family() {
    local id="$1" like="$2" expected="$3" actual
    actual="$(detect_host_family "$id" "$like")"
    if [[ "$actual" != "$expected" ]]; then
        printf 'FALLO: ID=%s ID_LIKE=%s: esperado %s, recibido %s\n' "$id" "$like" "$expected" "$actual" >&2
        exit 1
    fi
    printf 'OK: %-22s -> %s\n' "${id:-<vacío>} ${like}" "$actual"
}

assert_auto_install() {
    local family="$1" expected="$2"
    if host_family_supports_docker_install "$family"; then actual=true; else actual=false; fi
    [[ "$actual" == "$expected" ]] || { printf 'FALLO: auto instalación %s esperada=%s real=%s\n' "$family" "$expected" "$actual" >&2; exit 1; }
}

assert_family ubuntu '' debian
assert_family debian '' debian
assert_family linuxmint 'ubuntu debian' debian
assert_family arch '' arch
assert_family manjaro 'arch' arch
assert_family fedora '' fedora
assert_family rocky 'rhel fedora' rhel
assert_family almalinux 'rhel' rhel
assert_family opensuse-leap '' opensuse
assert_family opensuse-tumbleweed '' opensuse
assert_family sles '' opensuse
assert_family alpine '' alpine
assert_family unknown '' other
for family in arch fedora rhel opensuse alpine; do assert_auto_install "$family" true; done
for family in debian other; do assert_auto_install "$family" false; done
printf 'OK: detección de host y tabla de instalación Docker.\n'
