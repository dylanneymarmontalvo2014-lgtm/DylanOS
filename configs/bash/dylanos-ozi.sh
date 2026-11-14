# shellcheck shell=bash
# Easter egg opcional de DylanOS Console.
# Se carga solo en Bash interactivo desde dylanos.bashrc.
# El builtin echo se conserva para cualquier otro uso.
echo() {
    if [[ $# -eq 1 && $1 == 'ozi ozi' && $- == *i* && -t 0 && -t 1 ]]; then
        command python3 /usr/lib/dylanos/ozi-flappy.py
        return $?
    fi
    builtin echo "$@"
}
