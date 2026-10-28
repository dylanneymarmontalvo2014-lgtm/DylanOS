#!/usr/bin/env bash
#!/usr/bin/env bash
# Funciones puras para identificar hosts compatibles con la preparación del builder.

detect_host_family() {
    local id="${1,,}" id_like="${2,,}" token
    case "$id" in
        ubuntu|debian|linuxmint|pop|elementary) printf 'debian\n'; return ;;
        arch|manjaro|endeavouros|garuda|artix) printf 'arch\n'; return ;;
        fedora) printf 'fedora\n'; return ;;
        rhel|centos|rocky|almalinux|ol) printf 'rhel\n'; return ;;
        opensuse-leap|opensuse-tumbleweed|opensuse|sles|sled) printf 'opensuse\n'; return ;;
        alpine) printf 'alpine\n'; return ;;
    esac
    for token in $id_like; do
        case "$token" in
            debian|ubuntu) printf 'debian\n'; return ;;
            arch) printf 'arch\n'; return ;;
            fedora) printf 'fedora\n'; return ;;
            rhel|centos|rocky|almalinux) printf 'rhel\n'; return ;;
            suse|opensuse) printf 'opensuse\n'; return ;;
            alpine) printf 'alpine\n'; return ;;
        esac
    done
    printf 'other\n'
}

host_family_supports_docker_install() {
    case "$1" in
        arch|fedora|rhel|opensuse|alpine) return 0 ;;
        *) return 1 ;;
    esac
}

# 0 = el socket existe pero el usuario actual no puede usarlo. El daemon puede
# estar activo: /var/run/docker.sock es root:docker y el usuario no pertenece al
# grupo docker. Se usa solo cuando `docker info` ya falló.
docker_socket_permission_denied() {
    (( EUID == 0 )) && return 1
    [[ -S /var/run/docker.sock ]] || return 1
    id -nG 2>/dev/null | tr ' ' '\n' | grep -qx docker && return 1
    return 0
}
