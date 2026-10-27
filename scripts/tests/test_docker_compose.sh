#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/docker-compose.sh
. "$ROOT/scripts/docker-compose.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
PATH="$TMP/bin:/usr/bin:/bin"
export PATH

cat > "$TMP/bin/docker" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == compose && "$2" == version ]]; then
    [[ -n "${FAKE_PLUGIN_VERSION:-}" ]] || exit 1
    echo "${FAKE_PLUGIN_VERSION}"
    exit 0
fi
exit 1
SH
cat > "$TMP/bin/docker-compose" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == version ]]; then
    if [[ "$2" == --short ]]; then printf '%s\n' "${FAKE_STANDALONE:-}"; else printf 'Docker Compose version %s\n' "${FAKE_STANDALONE:-}"; fi
    exit 0
fi
exit 1
SH
chmod +x "$TMP/bin/docker" "$TMP/bin/docker-compose"

fail() { printf 'FALLO: %s\n' "$1" >&2; exit 1; }
FAKE_STANDALONE='2.27.0'
export FAKE_STANDALONE
[[ "$(dylanos_docker_compose_kind)" == standalone-v2 ]] || fail 'acepta Docker Compose standalone v2'
FAKE_PLUGIN_VERSION='Docker Compose version v2.27.0'
export FAKE_PLUGIN_VERSION
[[ "$(dylanos_docker_compose_kind)" == plugin ]] || fail 'prefiere el plugin Compose v2'
FAKE_PLUGIN_VERSION='Docker Compose version v1.29.2'
export FAKE_PLUGIN_VERSION
[[ "$(dylanos_docker_compose_kind)" == standalone-v2 ]] || fail 'rechaza plugin v1 y cae al standalone v2'
FAKE_PLUGIN_VERSION=''
export FAKE_PLUGIN_VERSION
FAKE_STANDALONE='1.29.2'
export FAKE_STANDALONE
if dylanos_docker_compose_available; then fail 'rechaza Compose v1'; fi
FAKE_STANDALONE='v2.24.6'
export FAKE_STANDALONE
[[ "$(dylanos_docker_compose_kind)" == standalone-v2 ]] || fail 'acepta versión standalone con prefijo v'
FAKE_STANDALONE='Docker Compose version v2.27.0'
export FAKE_STANDALONE
[[ "$(dylanos_docker_compose_kind)" == standalone-v2 ]] || fail 'acepta salida larga standalone v2'
printf 'OK: plugin Docker Compose y standalone v2; Compose v1 rechazado.\n'
