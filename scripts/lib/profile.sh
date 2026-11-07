#!/usr/bin/env bash
# Pure validation helpers for DylanOS package profiles.
# validate_dylanos_resume_profile <chroot> <requested-profile> <work-profile-file>
validate_dylanos_resume_profile() {
    local chroot="$1" requested="$2" work_profile_file="$3"
    local chroot_profile_file="$chroot/etc/dylanos-profile"
    local chroot_profile work_profile
    if [[ ! -f "$chroot_profile_file" || ! -f "$work_profile_file" ]]; then
        echo "No se puede reanudar con seguridad: falta el perfil registrado en $chroot_profile_file o $work_profile_file. Conservé el chroot; revísalo antes de continuar." >&2
        return 1
    fi
    chroot_profile="$(<"$chroot_profile_file")"
    work_profile="$(<"$work_profile_file")"
    if [[ "$chroot_profile" != "$requested" || "$work_profile" != "$requested" ]]; then
        echo "El chroot corresponde al perfil '$chroot_profile' (registro work: '$work_profile'), no a '$requested'. Conservé el chroot; usa el perfil original o prepara un work nuevo conscientemente." >&2
        return 1
    fi
    return 0
}
