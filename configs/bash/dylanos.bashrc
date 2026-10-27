# ~/.bashrc de DylanOS
# shellcheck shell=bash
# Prompt Crimson moderno (línea info + chevron), sugerencias fantasma y neofetch.

# Sin interactividad, no hacer nada.
case $- in
    *i*) ;;
      *) return;;
esac

# ───────────────────────────── Historial ─────────────────────────────
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT='%F %T  '
shopt -s histappend checkwinsize autocd 2>/dev/null
shopt -s cmdhist 2>/dev/null

# Completado y colores estándar.
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias actualizar='sudo apt update && sudo apt full-upgrade'
alias instalar='sudo apt install'
alias buscar='apt search'
alias sistema='neofetch'

# ───────────────────────── Paleta Crimson ──────────────────────────
DYL_CRIMSON='\[\e[1;38;5;196m\]'
DYL_RESET='\[\e[0m\]'

_DYL_RED='\e[1;38;5;196m'
_DYL_ROSE='\e[38;5;203m'
_DYL_WHITE='\e[1;38;5;255m'
_DYL_GRAY='\e[38;5;245m'
_DYL_DIM='\e[38;5;238m'
_DYL_OFF='\e[0m'

# ─────────── Prompt moderno de DylanOS (info + chevron ❯) ──────────
__dylanos_prompt_command() {
    local ec=$?
    local cols
    cols=$(tput cols 2>/dev/null) || cols=80

    # Título de ventana
    printf '\e]0;DylanOS Console — %s@%s: %s\a' \
        "${USER}" "$(hostname -s 2>/dev/null)" "${PWD/#$HOME/~}"

    # Indicador: ○ éxito, ● error
    local circle='○' circle_clr="$_DYL_WHITE"
    if [ "$ec" -ne 0 ]; then
        circle='●'; circle_clr="$_DYL_RED"
    fi

    local user="${USER}"
    local dir="${PWD/#$HOME/\~}"
    local now
    now=$(date +%H:%M)

    # Rama de git (si existe)
    local git_seg="" git_plain=""
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || true
    if [ -n "$branch" ]; then
        git_seg=" ${_DYL_ROSE}${branch}${_DYL_OFF}"
        git_plain=" ${branch}"
    fi

    # Relleno punteado hasta el borde derecho
    local plain_left="[ ${circle} ${user} ] [ ${dir} ]${git_plain} "
    local plain_right=" © ${now}"
    local fill=$(( cols - ${#plain_left} - ${#plain_right} ))
    [ "$fill" -lt 3 ] && fill=3

    local dots='' i=0
    while [ "$i" -lt "$fill" ]; do
        dots="${dots}·"; i=$((i + 1))
    done

    # Línea informativa con relleno punteado
    local line="${_DYL_GRAY}[ "
    line+="${circle_clr}${circle}${_DYL_OFF} "
    line+="${_DYL_WHITE}${user}${_DYL_OFF} "
    line+="${_DYL_GRAY}] [ "
    line+="${_DYL_WHITE}${dir}${_DYL_OFF} "
    line+="${_DYL_GRAY}]${_DYL_OFF}"
    line+="${git_seg} "
    line+="${_DYL_DIM}${dots}${_DYL_OFF}"
    line+=" ${_DYL_GRAY}© ${now}${_DYL_OFF}"
    printf '%b\n' "$line"
}
PROMPT_COMMAND=__dylanos_prompt_command

# ─────────────────────── Prompt de DylanOS ──────────────────────────
PS1="${DYL_CRIMSON}❯ ${DYL_RESET}"
PS2="${DYL_CRIMSON}· ${DYL_RESET}"

# ─────────────── Recomendaciones al escribir mal un comando ────────
command_not_found_handle() {
    local cmd="$1"
    local hint=""
    case "$cmd" in
        sl|dc|l) hint='ls' ;;
        gti|gt) hint='git' ;;
        gs) hint='git status' ;;
        gl) hint='git log --oneline' ;;
        aptget) hint='apt-get' ;;
        'ap install'*|ap*) hint='apt install' ;;
        isntall|instalar*) hint='instalar <paquete> (alias de apt install)' ;;
        pyhton|pytohn) hint='python3' ;;
        nmp) hint='npm' ;;
        fastftch) hint='neofetch (o el alias sistema)' ;;
        sistema*) hint='neofetch' ;;
        cd..) hint='cd ..' ;;
        gerp) hint='grep' ;;
        vi) hint='vim (o nano para empezar)' ;;
        konsole) hint='dylanos-console (Kitty)' ;;
        exit*) return 127 ;;
    esac
    printf '%b\342\224\200 Comando no encontrado: %b%s%b\n' "$_DYL_GRAY" "$_DYL_RED" "$cmd" "$_DYL_OFF"
    if [ -n "$hint" ]; then
        printf '%b   \342\226\272 Quisiste decir: %b%s%b\n' "$_DYL_GRAY" "$_DYL_WHITE" "$hint" "$_DYL_OFF"
    else
        printf '%b   \342\226\272 Busca software con: %bapt search %s%b\n' "$_DYL_GRAY" "$_DYL_WHITE" "$cmd" "$_DYL_OFF"
    fi
    return 127
}

# Sugerencia fantasma mientras se escribe (Tab la acepta).
if [ -f /usr/share/dylanos/shell/dylanos-ghost.sh ]; then
    # shellcheck source=configs/bash/dylanos-ghost.sh
    . /usr/share/dylanos/shell/dylanos-ghost.sh
fi

# ───────────────── Tip de DylanOS al abrir el terminal ──────────────
__dylanos_tip() {
    local tips=(
        'neofetch                   resumen completo del sistema'
        'dylanos-spotlight          abre el buscador (Ctrl+Espacio)'
        'actualizar                 actualiza todo el sistema (alias)'
        'instalar <paquete>         instala software (alias de apt install)'
        'buscar <texto>             encuentra paquetes disponibles'
        'journalctl -xe             revisa los registros del sistema'
        'df -h                      espacio libre en tus discos'
        'systemctl reboot           reinicia el equipo'
        'dylanos --page monitor     abre el Monitor del sistema'
        'nano <archivo>             editor de texto sencillo'
        'Tab                        acepta la sugerencia en gris'
    )
    local idx=$((RANDOM % ${#tips[@]}))
    printf '%b\342\224\200\342\224\200\342\224\200 Tip de DylanOS %b%s%b\n' "$_DYL_ROSE" "$_DYL_WHITE" "${tips[$idx]}" "$_DYL_OFF"
}

# neofetch en el primer shell interactivo gráfico de la sesión.
if [ "${SHLVL}" -eq 1 ] && [ -z "${DYLANOS_NO_NEOFETCH:-}" ] && command -v neofetch >/dev/null 2>&1; then
    neofetch
    printf '\n'
    __dylanos_tip
    printf '\n'
fi
