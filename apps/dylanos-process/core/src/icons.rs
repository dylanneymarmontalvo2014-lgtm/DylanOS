//! Resolución de iconos contra el tema real del sistema.
//!
//! No hay iconos embebidos ni colores por proceso: se busca el nombre de icono
//! en el tema activo de KDE (`kdeglobals` → `IconTheme`) y, si ahí no está, en
//! `hicolor`. Cada ejecutable se asocia a su icono leyendo los `.desktop`
//! instalados (`Exec=` → `Icon=`), que es la misma fuente que usa el menú.

use std::collections::{BTreeMap, HashMap};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

/// Tema de iconos configurado por el usuario, con su cadena de herencia.
pub fn active_theme(icon_root: &Path) -> String {
    if let Some(name) = configured_theme() {
        if icon_root.join(&name).is_dir() {
            return name;
        }
    }
    // Sin preferencia legible se usa el tema de KDE por defecto de DylanOS.
    for candidate in ["DylanIcons-Crimson", "breeze", "hicolor"] {
        if icon_root.join(candidate).is_dir() {
            return candidate.to_string();
        }
    }
    "hicolor".to_string()
}

fn configured_theme() -> Option<String> {
    let base = env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))?;
    let text = fs::read_to_string(base.join("kdeglobals")).ok()?;
    read_icon_theme(&text)
}

/// Lee `[Icons] Theme=` de un kdeglobals (KDE 6); `IconTheme=` se acepta por
/// compatibilidad con configuraciones antiguas.
pub fn read_icon_theme(text: &str) -> Option<String> {
    let mut in_icons = false;
    for line in text.lines() {
        let line = line.trim();
        if line.starts_with('[') {
            in_icons = line.eq_ignore_ascii_case("[Icons]");
            continue;
        }
        if in_icons {
            for key in ["Theme=", "IconTheme="] {
                if let Some(value) = line.strip_prefix(key) {
                    let value = value.trim();
                    if !value.is_empty() {
                        return Some(value.to_string());
                    }
                }
            }
        }
    }
    None
}

/// Cadenas de herencia declaradas en el `index.theme` del tema.
pub fn theme_inherits(icon_root: &Path, theme: &str) -> Vec<String> {
    let path = icon_root.join(theme).join("index.theme");
    let text = match fs::read_to_string(path) {
        Ok(t) => t,
        Err(_) => return Vec::new(),
    };
    let mut in_icons = false;
    for line in text.lines() {
        let line = line.trim();
        if line.starts_with('[') {
            in_icons = line.eq_ignore_ascii_case("[Icon Theme]");
            continue;
        }
        if in_icons {
            if let Some(value) = line.strip_prefix("Inherits=") {
                return value
                    .split(',')
                    .map(|v| v.trim().to_string())
                    .filter(|v| !v.is_empty())
                    .collect();
            }
        }
    }
    Vec::new()
}

/// Todos los iconos del sistema indexados por nombre, en orden de prioridad.
///
/// Se construye una sola vez al arrancar: indexar los temas cuesta milisegundos
/// y evita un `stat` por proceso y por refresco.
#[derive(Debug, Default)]
pub struct IconIndex {
    by_name: HashMap<String, PathBuf>,
}

impl IconIndex {
    /// Indexa el tema activo, sus herencias y `hicolor`.
    pub fn scan(icon_root: &Path) -> Self {
        let mut themes = Vec::new();
        let active = active_theme(icon_root);
        themes.push(active.clone());
        themes.extend(theme_inherits(icon_root, &active));
        for fallback in ["breeze", "hicolor"] {
            if !themes.iter().any(|t| t == fallback) {
                themes.push(fallback.to_string());
            }
        }

        let mut by_name = HashMap::new();
        // El primer tema de la lista gana: no se sobrescribe lo ya resuelto.
        for theme in themes {
            let dir = icon_root.join(&theme);
            if !dir.is_dir() {
                continue;
            }
            collect_theme(&dir, &mut by_name);
        }
        Self { by_name }
    }

    /// Ruta del icono, si el tema lo tiene.
    pub fn path(&self, name: &str) -> Option<&Path> {
        self.by_name.get(name).map(|p| p.as_path())
    }

    pub fn len(&self) -> usize {
        self.by_name.len()
    }

    pub fn is_empty(&self) -> bool {
        self.by_name.is_empty()
    }
}

fn collect_theme(dir: &Path, by_name: &mut HashMap<String, PathBuf>) {
    // Un tema agrupa por categoría (apps, actions, …) y luego por tamaño o
    // variante (scalable, 48, symbolic…). Se recorren los dos niveles.
    let categories = match fs::read_dir(dir) {
        Ok(entries) => entries,
        Err(_) => return,
    };
    for category in categories.flatten() {
        let category_path = category.path();
        if !category_path.is_dir() {
            continue;
        }
        let sizes = match fs::read_dir(&category_path) {
            Ok(entries) => entries,
            Err(_) => continue,
        };
        for size in sizes.flatten() {
            let size_path = size.path();
            if !size_path.is_dir() {
                continue;
            }
            let files = match fs::read_dir(&size_path) {
                Ok(entries) => entries,
                Err(_) => continue,
            };
            for file in files.flatten() {
                let path = file.path();
                let stem = match path.file_stem().and_then(|s| s.to_str()) {
                    Some(s) => s.to_string(),
                    None => continue,
                };
                // Se prefiere SVG (escala sin pérdida) sobre PNG.
                match by_name.get(&stem) {
                    Some(existing) if !is_svg(existing) || is_svg(&path) => {}
                    _ => {
                        by_name.insert(stem, path);
                    }
                }
            }
        }
    }
}

fn is_svg(path: &Path) -> bool {
    path.extension().and_then(|e| e.to_str()) == Some("svg")
}

/// Nombres e iconos declarados por los `.desktop` instalados, por ejecutable.
///
/// Un mismo comando (`dylanos`) puede tener varios lanzadores; se conserva la
/// primera entrada para no depender del orden de los directorios.
#[derive(Debug, Default)]
pub struct DesktopIndex {
    by_exec: HashMap<String, DesktopApp>,
}

/// Datos visibles de un lanzador: nombre y tema de icono.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DesktopApp {
    pub name: String,
    pub icon: String,
}

impl DesktopIndex {
    pub fn scan(dirs: &[PathBuf]) -> Self {
        let mut by_exec = HashMap::new();
        for dir in dirs {
            let entries = match fs::read_dir(dir) {
                Ok(entries) => entries,
                Err(_) => continue,
            };
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) != Some("desktop") {
                    continue;
                }
                let text = match fs::read_to_string(&path) {
                    Ok(t) => t,
                    Err(_) => continue,
                };
                if text.contains("NoDisplay=true") || text.contains("Hidden=true") {
                    continue;
                }
                let fields = parse_desktop_entry(&text);
                let exec = match fields.get("Exec") {
                    Some(e) => executable_name(e),
                    None => continue,
                };
                let icon = match fields.get("Icon") {
                    Some(i) if !i.trim().is_empty() => i.trim().to_string(),
                    _ => continue,
                };
                // `Name` sin localizar es el nombre base del lanzador.
                let name = fields
                    .get("Name")
                    .map(|n| n.trim().to_string())
                    .filter(|n| !n.is_empty())
                    .unwrap_or_else(|| exec.clone());
                by_exec.entry(exec).or_insert(DesktopApp { name, icon });
            }
        }
        Self { by_exec }
    }

    pub fn icon_for(&self, executable: &str) -> Option<&str> {
        self.by_exec.get(executable).map(|a| a.icon.as_str())
    }

    pub fn name_for(&self, executable: &str) -> Option<&str> {
        self.by_exec.get(executable).map(|a| a.name.as_str())
    }
}

/// Campos de la sección `[Desktop Entry]` de un `.desktop`.
pub fn parse_desktop_entry(text: &str) -> BTreeMap<String, String> {
    let mut fields = BTreeMap::new();
    let mut in_entry = false;
    for line in text.lines() {
        let line = line.trim();
        if line.starts_with('[') {
            in_entry = line == "[Desktop Entry]";
            continue;
        }
        if !in_entry || line.starts_with('#') {
            continue;
        }
        if let Some((key, value)) = line.split_once('=') {
            fields.entry(key.trim().to_string()).or_insert_with(|| value.trim().to_string());
        }
    }
    fields
}

/// Primer token de un `Exec=`, sin comillas ni marcadores de campo `%f`.
pub fn executable_name(exec: &str) -> String {
    let mut rest = exec.trim();
    // Los prefijos que alteran el entorno no son el ejecutable.
    while let Some(stripped) = rest.strip_prefix("env ") {
        rest = stripped.trim_start();
        // Salta las asignaciones VAR=valor del env.
        while let Some(space) = rest.find(' ') {
            if rest[..space].contains('=') {
                rest = rest[space + 1..].trim_start();
            } else {
                break;
            }
        }
    }
    let comando = if let Some(stripped) = rest.strip_prefix('"') {
        stripped.split('"').next().unwrap_or("")
    } else {
        rest.split_whitespace().next().unwrap_or("")
    };
    Path::new(comando)
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("")
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lee_el_tema_de_kdeglobals() {
        // kdeglobals real de DylanOS usa `Theme=` dentro de [Icons].
        let text = "[General]\nColorScheme=DylanOSCrimson\n\n[Icons]\nTheme=DylanIcons-Crimson\n";
        assert_eq!(read_icon_theme(text).as_deref(), Some("DylanIcons-Crimson"));
    }

    #[test]
    fn acepta_la_clave_antigua_icontheme() {
        let text = "[Icons]\nIconTheme=breeze\n";
        assert_eq!(read_icon_theme(text).as_deref(), Some("breeze"));
    }

    #[test]
    fn sin_seccion_icons_no_hay_tema() {
        let text = "[General]\nTheme=breeze\n";
        assert_eq!(read_icon_theme(text), None);
    }

    #[test]
    fn exec_simple() {
        assert_eq!(executable_name("dylanos-process"), "dylanos-process");
        assert_eq!(executable_name("/usr/bin/dylanos --page monitor"), "dylanos");
        assert_eq!(executable_name("kitty --class org.dylanos.console"), "kitty");
    }

    #[test]
    fn exec_entre_comillas_y_con_campos() {
        assert_eq!(executable_name("\"/opt/App/app\" %U"), "app");
    }

    #[test]
    fn exec_con_env() {
        assert_eq!(
            executable_name("env BAMF_DESKTOP_FILE_HINT=/x.desktop /usr/bin/code %F"),
            "code"
        );
    }

    #[test]
    fn desktop_entry_ignora_acciones_secundarias() {
        let text = "[Desktop Entry]\nName=DylanOS Process\nExec=dylanos-process\nIcon=dylanos-process\nNoDisplay=false\n\n[Desktop Action new]\nExec=otra\n";
        let fields = parse_desktop_entry(text);
        assert_eq!(fields.get("Exec").map(|s| s.as_str()), Some("dylanos-process"));
        assert_eq!(fields.get("Icon").map(|s| s.as_str()), Some("dylanos-process"));
        assert_eq!(fields.get("Name").map(|s| s.as_str()), Some("DylanOS Process"));
        // El Exec de la acción no debe sobrescribir el del lanzador.
        assert!(!fields.values().any(|v| v == "otra"));
    }
}
