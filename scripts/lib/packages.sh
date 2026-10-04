#!/usr/bin/env bash
# Funciones puras de manejo de paquetes de DylanOS.
# Este archivo se incluye (source) desde build.sh y desde los tests;
# no debe tener efectos secundarios al cargarse.

# parse_package_list <archivo>
# Imprime un paquete por línea a partir de una lista de paquetes.
# - Ignora líneas vacías y comentarios (# al inicio o al final de línea)
# - Recorta espacios y tabuladores alrededor del nombre
# - Elimina retornos de carro (listas guardadas con finales CRLF)
# - Conserva el orden del archivo
# Falla (exit != 0) si el archivo no existe.
parse_package_list() {
    local file="$1"

    if [ ! -f "$file" ]; then
        echo "ERROR: lista de paquetes no encontrada: $file" >&2
        return 1
    fi

    awk '
        { sub(/\r$/, ""); sub(/#.*/, ""); gsub(/^[ \t]+|[ \t]+$/, "") }
        NF {
            if ($0 !~ /^[a-z0-9][a-z0-9+.-]*(:[a-z0-9-]+)?$/) {
                print "ERROR: paquete inválido: " $0 > "/dev/stderr"; exit 1
            }
            print
        }
    ' "$file"
}
