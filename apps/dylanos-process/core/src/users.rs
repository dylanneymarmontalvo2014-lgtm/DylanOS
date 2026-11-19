//! Resolución de usuarios reales mediante `getpwuid_r`.
//!
//! Se cachea uid→nombre: los procesos comparten dueño y resolver con NSS en
//! cada muestra costaría una consulta por proceso (posible LDAP/NIS).

use std::collections::HashMap;
use std::ffi::{c_char, c_int, CStr};

#[repr(C)]
struct Passwd {
    pw_name: *mut c_char,
    pw_passwd: *mut c_char,
    pw_uid: u32,
    pw_gid: u32,
    pw_gecos: *mut c_char,
    pw_dir: *mut c_char,
    pw_shell: *mut c_char,
}

extern "C" {
    fn getpwuid_r(
        uid: u32,
        pwd: *mut Passwd,
        buf: *mut c_char,
        buflen: usize,
        result: *mut *mut Passwd,
    ) -> c_int;
}

/// Traduce un uid a su nombre de usuario del sistema.
pub fn lookup_uid(uid: u32) -> Option<String> {
    let mut buf = vec![0_i8; 16 * 1024];
    let mut pwd = Passwd {
        pw_name: std::ptr::null_mut(),
        pw_passwd: std::ptr::null_mut(),
        pw_uid: 0,
        pw_gid: 0,
        pw_gecos: std::ptr::null_mut(),
        pw_dir: std::ptr::null_mut(),
        pw_shell: std::ptr::null_mut(),
    };
    let mut result: *mut Passwd = std::ptr::null_mut();
    // SAFETY: buf y pwd viven hasta el final de la función y tienen el tamaño
    // declarado; getpwuid_r solo escribe dentro de ellos.
    let rc = unsafe { getpwuid_r(uid, &mut pwd, buf.as_mut_ptr(), buf.len(), &mut result) };
    if rc != 0 || result.is_null() || pwd.pw_name.is_null() {
        return None;
    }
    // SAFETY: pw_name apunta a buf, que sigue válido aquí.
    let name = unsafe { CStr::from_ptr(pwd.pw_name) };
    name.to_str().ok().map(|s| s.to_string())
}

/// Caché de uid→nombre para no repetir la consulta NSS.
#[derive(Debug, Default)]
pub struct UserCache {
    names: HashMap<u32, String>,
}

impl UserCache {
    pub fn new() -> Self {
        Self::default()
    }

    /// Nombre del usuario, o "—" si el uid no existe en el sistema.
    pub fn name(&mut self, uid: u32) -> &str {
        if !self.names.contains_key(&uid) {
            let name = lookup_uid(uid).unwrap_or_else(|| "—".to_string());
            self.names.insert(uid, name);
        }
        self.names.get(&uid).map(|s| s.as_str()).unwrap_or("—")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn root_siempre_existe() {
        assert_eq!(lookup_uid(0).as_deref(), Some("root"));
    }

    #[test]
    fn uid_inexistente_devuelve_none() {
        // 2^31-1 no es un uid asignable en la práctica.
        assert_eq!(lookup_uid(u32::MAX - 1), None);
    }

    #[test]
    fn la_cache_reutiliza_la_resolucion() {
        let mut cache = UserCache::new();
        assert_eq!(cache.name(0), "root");
        assert_eq!(cache.name(0), "root");
        assert_eq!(cache.names.len(), 1);
    }

    #[test]
    fn uid_desconocido_se_muestra_como_guion() {
        let mut cache = UserCache::new();
        assert_eq!(cache.name(u32::MAX - 1), "—");
    }
}
