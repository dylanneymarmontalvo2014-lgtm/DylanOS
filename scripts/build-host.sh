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
