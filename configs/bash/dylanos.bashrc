# ~/.bashrc de DylanOS
# shellcheck shell=bash
# Prompt Crimson, separadores con nombre, sugerencias fantasma y neofetch.

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
DYL_WHITE='\[\e[1;38;5;255m\]'
DYL_GRAY='\[\e[38;5;245m\]'
DYL_BLUE='\[\e[38;5;75m\]'
DYL_RESET='\[\e[0m\]'

_DYL_RED='\e[1;38;5;196m'
_DYL_ROSE='\e[38;5;203m'
_DYL_WHITE='\e[1;38;5;255m'
_DYL_GRAY='\e[38;5;245m'
_DYL_DIM='\e[38;5;238m'
_DYL_OFF='\e[0m'

# ─────────────── Rama de git para el prompt (si existe) ─────────────
__dylanos_git_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return 0
    printf ' %b\342\226\210 %b%s%b' "$_DYL_DIM" "$_DYL_ROSE" "$branch" "$_DYL_OFF"
}

# Separador con nombre entre comandos + título de la ventana.
__dylanos_prompt_command() {
    local columns title mark rest i
    columns=$(tput cols 2>/dev/null) || columns=80
    title=' DylanOS Console '
    mark='──'
    rest=$((columns - ${#title} - 4))
    [ "$rest" -lt 4 ] && rest=4
    printf '%b%s%s' "$_DYL_DIM" "$mark" "$title"
    i=0
    while [ "$i" -lt "$rest" ]; do
        printf '─'
        i=$((i + 1))
    done
    printf '%s%b\n' "$mark" "$_DYL_OFF"
    printf '\e]0;DylanOS Console — %s@%s: %s\a' "${USER}" "$(hostname -s 2>/dev/null)" "${PWD/#$HOME/~}"
}
PROMPT_COMMAND=__dylanos_prompt_command

# ─────────────────────── Prompt de DylanOS ──────────────────────────
PS1="${DYL_CRIMSON}\342\224\214\342\224\200\342\224\200${DYL_WHITE} ${DYL_CRIMSON}[${DYL_WHITE}\u${DYL_GRAY}@${DYL_WHITE}\h${DYL_CRIMSON}]${DYL_GRAY}-${DYL_CRIMSON}[${DYL_BLUE}\w${DYL_CRIMSON}]\$(__dylanos_git_branch)\n${DYL_CRIMSON}\342\224\224\342\224\200\342\224\200\342\226\266 ${DYL_RESET}"
PS2="${DYL_CRIMSON}\342\224\200\342\226\266 ${DYL_RESET}"

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
