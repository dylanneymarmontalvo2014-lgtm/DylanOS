//! Cambio real de prioridad de un proceso con `setpriority(2)`.
//!
//! Igual que las señales, los permisos son los del usuario: el kernel exige ser
//! dueño del proceso y, para valores negativos, capacidad `CAP_SYS_NICE`. El
//! error del kernel se propaga tal cual a la interfaz.

use std::ffi::c_int;
use std::io;

extern "C" {
    fn setpriority(which: c_int, who: u32, prio: c_int) -> c_int;
}

/// `PRIO_PROCESS` de Linux: el primer argumento de `setpriority`.
const PRIO_PROCESS: c_int = 0;

/// Cambia el `nice` de un proceso concreto.
///
/// El prototipo ofrece cuatro niveles; se traducen a valores de `nice` reales
/// (el rango del kernel es -20..19, donde menor es más prioritario).
pub fn set_nice(pid: i32, nice: i32) -> io::Result<()> {
    if pid <= 0 {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "PID inválido: solo se aceptan procesos reales del sistema",
        ));
    }
    // SAFETY: setpriority valida permisos y rango en el kernel.
    let rc = unsafe { setpriority(PRIO_PROCESS, pid as u32, nice) };
    if rc == 0 {
        Ok(())
    } else {
        Err(io::Error::last_os_error())
    }
}

/// Valor de `nice` para cada nivel del selector, en el orden del prototipo.
pub fn nice_for_level(level: usize) -> i32 {
    match level {
        0 => 10,    // Baja: menos prioridad
        1 => 0,     // Normal
        2 => -5,    // Alta
        _ => -15,   // Tiempo real: lo máximo sin privilegios de sistema
    }
}

/// Nivel del selector que corresponde a un `nice` real.
pub fn level_for_nice(nice: i32) -> usize {
    match nice {
        n if n >= 5 => 0,
        n if n >= -2 => 1,
        n if n >= -10 => 2,
        _ => 3,
    }
}

/// Etiquetas del selector, las mismas del prototipo.
pub const PRIORITY_LABELS: [&str; 4] = ["Baja", "Normal", "Alta", "Tiempo real"];

/// Mensaje en español para los errores típicos de `setpriority`.
///
/// El kernel responde `EACCES` (13) cuando se intenta subir la prioridad sin
/// `CAP_SYS_NICE`, y `EPERM` (1) cuando el proceso no es del usuario.
pub fn describe_error(error: &io::Error) -> &'static str {
    match error.raw_os_error() {
        Some(1) | Some(13) => "Permiso denegado: solo el propietario puede cambiar la prioridad.",
        Some(3) => "El proceso ya no existe.",
        Some(22) => "Prioridad fuera del rango permitido por el kernel.",
        _ => "No se pudo cambiar la prioridad del proceso.",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn los_niveles_cubren_el_rango_del_prototipo() {
        assert_eq!(nice_for_level(0), 10);
        assert_eq!(nice_for_level(1), 0);
        assert_eq!(nice_for_level(2), -5);
        assert_eq!(nice_for_level(3), -15);
    }

    #[test]
    fn ida_y_vuelta_entre_nivel_y_nice() {
        for level in 0..4 {
            let nice = nice_for_level(level);
            assert_eq!(level_for_nice(nice), level, "nivel {level} con nice {nice}");
        }
    }

    #[test]
    fn un_nice_arbitrario_cae_en_algun_nivel() {
        assert_eq!(level_for_nice(19), 0);
        assert_eq!(level_for_nice(0), 1);
        assert_eq!(level_for_nice(-20), 3);
    }

    #[test]
    fn cambia_la_prioridad_de_un_proceso_propio() {
        // Bajar la prioridad (subir el nice) siempre está permitido al dueño;
        // volver a subirla exige CAP_SYS_NICE. El test comprueba ambas caras
        // del modelo de permisos real del kernel, sin elevarnos privilegios.
        let pid = std::process::id() as i32;
        let original = unsafe { getpriority_local(pid) };
        set_nice(pid, original + 5).expect("bajar prioridad del propio proceso");
        assert_eq!(unsafe { getpriority_local(pid) }, original + 5);
        if original > -20 {
            match set_nice(pid, original) {
                Ok(()) => assert_eq!(unsafe { getpriority_local(pid) }, original),
                Err(error) => {
                    // Sin privilegios, el kernel deniega y el error se propaga.
                    assert_eq!(error.raw_os_error(), Some(13), "EPERM esperado");
                    assert_eq!(
                        describe_error(&error),
                        "Permiso denegado: solo el propietario puede cambiar la prioridad."
                    );
                }
            }
        }
    }

    #[test]
    fn rechaza_pids_no_positivos() {
        assert!(set_nice(0, 5).is_err());
        assert!(set_nice(-3, 5).is_err());
    }

    /// Lee el `nice` real del proceso creando `ps` sería dependiente del
    /// entorno; se usa `getpriority` vía `/proc` para no añadir otra FFI.
    unsafe fn getpriority_local(pid: i32) -> i32 {
        let text = std::fs::read_to_string(format!("/proc/{pid}/stat")).unwrap_or_default();
        let close = text.rfind(')').unwrap_or(0);
        // Campo 19 de stat (nice) contando desde 1 tras el comm: índice 16 del
        // resto, posición 18 del formato original.
        let fields: Vec<&str> = text[close + 1..].split_whitespace().collect();
        fields.get(16).and_then(|v| v.parse().ok()).unwrap_or(0)
    }
}
