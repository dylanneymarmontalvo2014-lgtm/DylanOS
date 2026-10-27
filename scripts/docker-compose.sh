#!/usr/bin/env bash
# Compatibilidad con el plugin `docker compose` y el binario standalone v2.
# Funciones puras: no instalan ni inician servicios.
dylanos_docker_compose_kind() {
    local version
    if command -v docker >/dev/null 2>&1; then
        version="$(docker compose version --short 2>/dev/null || docker compose version 2>/dev/null || true)"
        if grep -Eq '(^|[[:space:]])v?2\.[0-9]+([.]|[[:space:]]|$)' <<<"$version"; then
            printf 'plugin\n'
            return 0
        fi
    fi

    if command -v docker-compose >/dev/null 2>&1; then
        version="$(docker-compose version --short 2>/dev/null || docker-compose version 2>/dev/null || true)"
        if grep -Eq '(^|[[:space:]])v?2\.[0-9]+([.]|[[:space:]]|$)' <<<"$version"; then
            printf 'standalone-v2\n'
            return 0
        fi
    fi
    return 1
}

dylanos_docker_compose_available() {
    dylanos_docker_compose_kind >/dev/null
}
