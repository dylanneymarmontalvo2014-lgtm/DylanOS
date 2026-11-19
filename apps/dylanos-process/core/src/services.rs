//! Servicios reales del sistema a través de `systemctl`.
//!
//! Se usa el binario de systemd (no un socket propio): así los permisos son los
//! del usuario y polkit decide si una acción requiere autenticación. Nunca se
//! simula el resultado: si `systemctl` falla, el error real vuelve a la UI.

use std::io;
use std::process::Command;

/// Una unidad de servicio tal como la reporta systemd.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ServiceUnit {
    pub name: String,
    pub description: String,
    pub active: bool,
    /// `Sistema` para unidades del sistema, `Usuario` para la sesión.
    pub scope: &'static str,
}

/// Salida de un intento de acción sobre una unidad.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ServiceResult {
    pub ok: bool,
    pub message: String,
}

/// Interpreta `systemctl list-units --no-legend --plain`.
///
/// Cada línea útil es `unidad load active sub descripción…`. Se descartan las
/// unidades no cargadas (`not-found`) y los `●` que systemd antepone cuando hay
/// fallos, para no mostrar filas fantasma.
pub fn parse_list_units(text: &str, scope: &'static str) -> Vec<ServiceUnit> {
    let mut units = Vec::new();
    for line in text.lines() {
        // systemd antepone `●`/`×` a las unidades con fallo; no es parte del nombre.
        let line = line.trim_start_matches(['●', '×', '*', ' ']);
        if line.is_empty() {
            continue;
        }
        // La descripción puede llevar espacios, así que los cuatro primeros
        // campos se toman por separado y el resto es texto libre.
        let mut campos = line.split_whitespace();
        let name = match campos.next() {
            Some(n) if n.ends_with(".service") => n,
            _ => continue,
        };
        let load = campos.next().unwrap_or("");
        let active = campos.next().unwrap_or("");
        let _sub = campos.next().unwrap_or("");
        let description = campos.collect::<Vec<_>>().join(" ");
        // `not-found` y `masked` viven en la columna de carga, no en la de
        // estado: se descartan para no mostrar filas fantasma.
        if load == "not-found" || load == "masked" || active == "masked" {
            continue;
        }
        units.push(ServiceUnit {
            name: name.to_string(),
            description,
            active: active == "active",
            scope,
        });
    }
    units
}

/// Lista las unidades de servicio reales del sistema y de la sesión.
pub fn list_services() -> io::Result<Vec<ServiceUnit>> {
    let mut all = run_list(&["--system"])?;
    // Las unidades de usuario fallan en sesiones sin bus de usuario; no es un
    // error del monitor, así que se ignora el fallo y se conserva el sistema.
    if let Ok(user) = run_list(&["--user"]) {
        all.extend(user);
    }
    all.sort_by(|a, b| a.name.cmp(&b.name));
    all.dedup_by(|a, b| a.name == b.name && a.scope == b.scope);
    Ok(all)
}

fn run_list(scope_args: &[&str]) -> io::Result<Vec<ServiceUnit>> {
    let scope = if scope_args.contains(&"--user") { "Usuario" } else { "Sistema" };
    let mut cmd = Command::new("systemctl");
    cmd.args(scope_args);
    cmd.args([
        "list-units",
        "--type=service",
        "--all",
        "--no-legend",
        "--no-pager",
        "--plain",
    ]);
    let output = cmd.output()?;
    if !output.status.success() {
        return Err(io::Error::new(
            io::ErrorKind::Other,
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ));
    }
    let text = String::from_utf8_lossy(&output.stdout);
    Ok(parse_list_units(&text, scope))
}

/// Ejecuta `systemctl start|stop` sobre una unidad concreta.
///
/// `enable` no se toca: el monitor arranca y detiene el servicio ahora, no
/// cambia el arranque del sistema sin pedirlo.
pub fn set_service_active(unit: &str, active: bool, user_scope: bool) -> ServiceResult {
    let action = if active { "start" } else { "stop" };
    let mut cmd = Command::new("systemctl");
    if user_scope {
        cmd.arg("--user");
    }
    cmd.arg(action).arg(unit);
    match cmd.output() {
        Ok(output) if output.status.success() => ServiceResult {
            ok: true,
            message: format!(
                "{} {}",
                if active { "Servicio iniciado:" } else { "Servicio detenido:" },
                unit
            ),
        },
        Ok(output) => {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let detail = stderr
                .lines()
                .map(|l| l.trim())
                .filter(|l| !l.is_empty())
                .collect::<Vec<_>>()
                .join(" ");
            ServiceResult {
                ok: false,
                message: if detail.is_empty() {
                    format!("systemctl {action} {unit} falló con código {}", output.status)
                } else {
                    detail
                },
            }
        }
        Err(error) => ServiceResult {
            ok: false,
            message: format!("No se pudo ejecutar systemctl: {error}"),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SALIDA: &str = "  accounts-daemon.service        loaded active running Accounts Service\n  apparmor.service               loaded active exited  Load AppArmor profiles\n  avahi-daemon.service           loaded inactive dead  Avahi mDNS/DNS-SD Stack\n  dbus.service                   loaded active running D-Bus System Message Bus\n● roto.service                   loaded failed failed  Servicio roto\n  fantasma.service               not-found inactive dead fantasma.service\n  mask.service                   loaded masked inactive dead mask.service\n";

    #[test]
    fn parsea_unidades_activas_e_inactivas() {
        let units = parse_list_units(SALIDA, "Sistema");
        let names: Vec<&str> = units.iter().map(|u| u.name.as_str()).collect();
        assert_eq!(
            names,
            vec!["accounts-daemon.service", "apparmor.service", "avahi-daemon.service", "dbus.service", "roto.service"]
        );
        assert!(units[0].active);
        assert_eq!(units[0].description, "Accounts Service");
        assert!(!units[2].active, "avahi está inactivo");
    }

    #[test]
    fn descarta_unidades_no_encontradas_y_enmascaradas() {
        let units = parse_list_units(SALIDA, "Sistema");
        assert!(!units.iter().any(|u| u.name == "fantasma.service"));
        assert!(!units.iter().any(|u| u.name == "mask.service"));
    }

    #[test]
    fn ignora_lineas_que_no_son_servicios() {
        let text = "FOO bar baz\n \n1 unit listed\n";
        assert!(parse_list_units(text, "Sistema").is_empty());
    }

    #[test]
    fn conserva_el_ambito() {
        let units = parse_list_units("a.service loaded active running A\n", "Usuario");
        assert_eq!(units[0].scope, "Usuario");
    }
}
