//! Envío real de señales a procesos.
//!
//! Usa `kill(2)` directamente: los permisos son los del usuario de la sesión y
//! el kernel rechaza lo que no le corresponde. El resultado del kernel se
//! devuelve siempre a la UI, que nunca muestra un éxito inventado.

use std::ffi::c_int;
use std::io;

extern "C" {
    fn kill(pid: c_int, sig: c_int) -> c_int;
}

pub const SIGTERM: c_int = 15;
pub const SIGKILL: c_int = 9;

/// Termina un proceso con `SIGTERM`, dándole la oportunidad de cerrarse limpio.
pub fn terminate(pid: i32) -> io::Result<()> {
    send(pid, SIGTERM)
}

/// Termina un proceso con `SIGKILL`, sin oportunidad de limpieza.
pub fn force_terminate(pid: i32) -> io::Result<()> {
    send(pid, SIGKILL)
}

/// Envía una señal arbitraria y traduce `errno` a un error legible.
pub fn send(pid: i32, signal: c_int) -> io::Result<()> {
    if pid <= 0 {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "PID inválido: solo se aceptan procesos reales del sistema",
        ));
    }
    // SAFETY: kill es una syscall directa; el kernel valida el pid y los permisos.
    let rc = unsafe { kill(pid, signal) };
    if rc == 0 {
        Ok(())
    } else {
        Err(io::Error::last_os_error())
    }
}

/// Mensaje en español para los errores típicos del kernel al señalizar.
pub fn describe_error(error: &io::Error) -> &'static str {
    match error.raw_os_error() {
        Some(1) => "Permiso denegado: el proceso pertenece a otro usuario o al sistema.",
        Some(3) => "El proceso ya no existe.",
        _ => "No se pudo enviar la señal al proceso.",
    }
}

/// Comprueba si el proceso sigue vivo sin enviarle ninguna señal.
pub fn is_alive(pid: i32) -> bool {
    if pid <= 0 {
        return false;
    }
    // La señal 0 no se entrega: solo comprueba existencia y permisos.
    // SAFETY: misma syscall, señal 0 es una consulta sin efectos.
    unsafe { kill(pid, 0) == 0 }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::process::{Command, Stdio};
    use std::time::{Duration, Instant};

    fn spawn_sleep() -> std::process::Child {
        Command::new("sleep")
            .arg("30")
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .expect("sleep debe existir")
    }

    #[test]
    fn termina_un_proceso_real_propio() {
        let mut child = spawn_sleep();
        let pid = child.id() as i32;
        assert!(is_alive(pid), "el proceso debe estar vivo antes");
        terminate(pid).expect("SIGTERM al proceso propio permitido");
        let deadline = Instant::now() + Duration::from_secs(5);
        let mut exited = false;
        while Instant::now() < deadline {
            match child.try_wait() {
                Ok(Some(_)) => {
                    exited = true;
                    break;
                }
                Ok(None) => std::thread::sleep(Duration::from_millis(20)),
                Err(_) => break,
            }
        }
        assert!(exited, "el proceso debe terminar tras SIGTERM");
        let status = child.wait().expect("recolección");
        assert!(!status.success(), "SIGTERM no es una salida exitosa");
    }

    #[test]
    fn fuerza_la_terminacion_de_un_proceso_real() {
        let mut child = spawn_sleep();
        let pid = child.id() as i32;
        force_terminate(pid).expect("SIGKILL al proceso propio permitido");
        let status = child.wait().expect("recolección");
        assert!(!status.success());
        assert!(!is_alive(pid), "ya no debe existir");
    }

    #[test]
    fn error_legible_para_pid_inexistente() {
        // 2^31-2 no es un pid utilizable; el kernel responde ESRCH.
        let error = terminate(i32::MAX - 2).expect_err("un pid absurdo debe fallar");
        assert_eq!(describe_error(&error), "El proceso ya no existe.");
    }

    #[test]
    fn rechaza_pids_no_positivos_sin_llamar_al_kernel() {
        assert!(terminate(0).is_err());
        assert!(terminate(-1).is_err());
        assert!(!is_alive(0));
    }

    #[test]
    fn no_puede_matar_proceso_de_otro_usuario() {
        if std::env::var("USER").as_deref() == Ok("root") {
            return; // root puede: la comprobación no aplica.
        }
        // PID 1 pertenece a root; el kernel debe denegarlo o ESRCH en contenedores.
        match terminate(1) {
            Ok(()) => panic!("un usuario normal no debe poder terminar PID 1"),
            Err(error) => {
                let message = describe_error(&error);
                assert!(
                    message.starts_with("Permiso denegado") || message.starts_with("El proceso ya no existe"),
                    "mensaje inesperado: {message}"
                );
            }
        }
    }
}
