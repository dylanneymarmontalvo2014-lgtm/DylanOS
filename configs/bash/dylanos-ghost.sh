# Recomendador de DylanOS Console: completa desde el historial o los comandos.
# shellcheck shell=bash
# Se carga solo desde shells interactivos (dylanos.bashrc).

# Evita redefinir binds si el archivo se sourcea dos veces.
[ -n "${DYLANOS_GHOST_LOADED:-}" ] && return
DYLANOS_GHOST_LOADED=1
DYLANOS_GHOST=""

__dylanos_ghost_find() {
    DYLANOS_GHOST=""
    local line="${READLINE_LINE-}"
    local point="${READLINE_POINT-0}"
    [ -z "$line" ] && return
    [ "$point" -ne "${#line}" ] && return

    local hist=""
    hist=$(fc -ln -120 2>/dev/null | sed 's/^[[:space:]]*//' | awk -v p="$line" 'index($0,p)==1 && $0!=p {print; exit}')
    if [ -n "$hist" ]; then
        DYLANOS_GHOST="${hist#"$line"}"
        return
    fi

    if [[ "$line" != *' '* ]]; then
        local cmd=""
        cmd=$(compgen -c -- "$line" 2>/dev/null | awk -v p="$line" '$0!=p && index($0,p)==1 {print; exit}')
        if [ -n "$cmd" ]; then
            DYLANOS_GHOST="${cmd#"$line"}"
        fi
    fi
}

__dylanos_ghost_accept() {
    [ -z "${DYLANOS_GHOST:-}" ] && __dylanos_ghost_find
    if [ -n "${DYLANOS_GHOST:-}" ] && [ "${READLINE_POINT-0}" -eq "${#READLINE_LINE}" ]; then
        READLINE_LINE="${READLINE_LINE}${DYLANOS_GHOST}"
        READLINE_POINT=${#READLINE_LINE}
        DYLANOS_GHOST=""
        printf '\e[K'
        return 0
    fi
    return 1
}

__dylanos_tab() {
    if __dylanos_ghost_accept; then
        return
    fi
    local line="${READLINE_LINE-}"
    local point="${READLINE_POINT-0}"
    local prefix="${line:0:point}"
    local token="${prefix##* }"
    local comps=()
    if [ -z "$token" ]; then
        return
    fi
    if [ "$prefix" = "$token" ]; then
        mapfile -t comps < <(compgen -c -- "$token" 2>/dev/null | sort -u)
    else
        mapfile -t comps < <(compgen -f -- "$token" 2>/dev/null | sort)
    fi
    local n=${#comps[@]}
    if [ "$n" -eq 1 ]; then
        local extra="${comps[0]#"$token"}"
        READLINE_LINE="${line:0:point}${extra}${line:point}"
        READLINE_POINT=$((point + ${#extra}))
    elif [ "$n" -gt 1 ]; then
        printf '\n'
        printf '%s  ' "${comps[@]:0:30}"
        printf '\n'
        if [ "$n" -gt 30 ]; then
            printf '… %s más\n' "$((n - 30))"
        fi
    fi
}

__dylanos_right() {
    if __dylanos_ghost_accept; then
        return
    fi
    if [ "${READLINE_POINT-0}" -lt "${#READLINE_LINE}" ]; then
        READLINE_POINT=$((READLINE_POINT + 1))
    fi
}

if [[ $- == *i* ]] && [ -n "${BASH_VERSION:-}" ] && [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
    # La sugerencia se calcula al pulsar Tab o flecha derecha. Pintarla tras
    # cada tecla con macros de Readline provocaba "maximum macro execution
    # nesting level exceeded" y bloqueaba la entrada de comandos.
    bind -x '"\t": __dylanos_tab'
    bind -x '"\e[C": __dylanos_right'
fi
