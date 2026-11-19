//! Muestreador del sistema: lee /proc y calcula los deltas entre refrescos.

use std::collections::HashMap;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use crate::icons::{DesktopIndex, IconIndex};
use crate::parse::{self, IoCounters};
use crate::users::UserCache;

/// Estado tal como lo entiende la UI (mismos textos que el prototipo).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProcState {
    Running,
    Sleeping,
    DiskWait,
    Zombie,
    Stopped,
    Idle,
    Unknown,
}

impl ProcState {
    pub fn from_char(c: char) -> Self {
        match c {
            'R' => ProcState::Running,
            'S' => ProcState::Sleeping,
            'D' => ProcState::DiskWait,
            'Z' => ProcState::Zombie,
            'T' | 't' => ProcState::Stopped,
            'I' => ProcState::Idle,
            _ => ProcState::Unknown,
        }
    }

    /// Etiqueta visible en español, la misma del prototipo.
    pub fn label(self) -> &'static str {
        match self {
            ProcState::Running => "Ejecutando",
            ProcState::Sleeping => "Suspendido",
            ProcState::DiskWait => "Espera de E/S",
            ProcState::Zombie => "Zombi",
            ProcState::Stopped => "Detenido",
            ProcState::Idle => "Inactivo",
            ProcState::Unknown => "Desconocido",
        }
    }
}

/// Una fila de proceso lista para pintar.
#[derive(Debug, Clone)]
pub struct ProcRow {
    pub pid: i32,
    pub ppid: i32,
    pub name: String,
    pub command: String,
    pub user: String,
    pub uid: u32,
    /// Porcentaje de CPU normalizado por núcleos (0–100 por núcleo disponible).
    pub cpu: f32,
    /// Memoria residente en bytes.
    pub rss: u64,
    pub swap_kb: u64,
    pub state: ProcState,
    pub threads: u32,
    pub priority: i32,
    pub nice: i32,
    /// Icono del tema resuelto, si existe.
    pub icon: Option<String>,
    /// Bytes leídos/escritos acumulados por el proceso.
    pub io: IoCounters,
    /// Segundos desde que arrancó el proceso.
    pub uptime_secs: u64,
}

/// Foto global del sistema en un instante.
#[derive(Debug, Clone, Default)]
pub struct Snapshot {
    pub processes: Vec<ProcRow>,
    pub total_threads: u64,
    pub cpu_percent: f32,
    pub mem: parse::MemInfo,
    pub net_rx: u64,
    pub net_tx: u64,
    pub disk_read: u64,
    pub disk_write: u64,
    pub load: (f32, f32, f32),
    pub uptime_secs: f64,
    pub cores: u32,
}

impl Snapshot {
    pub fn mem_used_bytes(&self) -> u64 {
        self.mem.used_kb() * 1024
    }

    pub fn mem_total_bytes(&self) -> u64 {
        self.mem.total_kb * 1024
    }

    pub fn swap_used_bytes(&self) -> u64 {
        self.mem.swap_used_kb() * 1024
    }

    pub fn swap_total_bytes(&self) -> u64 {
        self.mem.swap_total_kb * 1024
    }
}

/// Tasas de red y disco entre dos muestras (bytes por segundo).
#[derive(Debug, Clone, Copy, Default)]
pub struct Rates {
    pub net_rx: f64,
    pub net_tx: f64,
    pub disk_read: f64,
    pub disk_write: f64,
}

/// Muestreador con memoria del refresco anterior para calcular deltas.
pub struct Sampler {
    root: PathBuf,
    cores: u32,
    user_cache: UserCache,
    icons: IconIndex,
    desktops: DesktopIndex,
    last_cpu: Option<(u64, u64)>,
    last_proc_ticks: HashMap<i32, (u64, u64)>,
    last_net: Option<(u64, u64)>,
    last_disk: Option<(u64, u64)>,
    last_instant: Option<Instant>,
    last_rates: Rates,
}

impl Sampler {
    /// Crea el muestreador leyendo del `/proc` del sistema.
    pub fn new() -> Self {
        Self::with_root(Path::new("/proc"))
    }

    /// Igual que `new`, pero leyendo de otro `/proc` (tests con fixtures).
    pub fn with_root(root: &Path) -> Self {
        let icon_root = PathBuf::from("/usr/share/icons");
        let desktop_dirs = default_desktop_dirs();
        Self {
            root: root.to_path_buf(),
            cores: num_cores() as u32,
            user_cache: UserCache::new(),
            icons: IconIndex::scan(&icon_root),
            desktops: DesktopIndex::scan(&desktop_dirs),
            last_cpu: None,
            last_proc_ticks: HashMap::new(),
            last_net: None,
            last_disk: None,
            last_instant: None,
            last_rates: Rates::default(),
        }
    }

    pub fn cores(&self) -> u32 {
        self.cores
    }

    pub fn rates(&self) -> Rates {
        self.last_rates
    }

    fn read(&self, relative: &str) -> io::Result<String> {
        fs::read_to_string(self.root.join(relative))
    }

    fn read_bytes(&self, relative: &str) -> io::Result<Vec<u8>> {
        fs::read(self.root.join(relative))
    }

    /// Toma una muestra completa. El primer refresco devuelve CPU en 0 porque
    /// todavía no hay delta que calcular (igual que top en su primera línea).
    pub fn sample(&mut self) -> Snapshot {
        let now = Instant::now();
        let elapsed = self
            .last_instant
            .map(|t| now.duration_since(t).as_secs_f64())
            .unwrap_or(0.0);

        let mut snap = Snapshot {
            cores: self.cores,
            ..Snapshot::default()
        };

        if let Ok(text) = self.read("meminfo") {
            snap.mem = parse::parse_meminfo(&text);
        }
        if let Ok(text) = self.read("loadavg") {
            snap.load = parse::parse_loadavg(&text);
        }
        if let Ok(text) = self.read("uptime") {
            snap.uptime_secs = parse::parse_uptime(&text);
        }

        if let Ok(text) = self.read("stat") {
            if let Some((total, idle)) = parse::parse_cpu_totals(&text) {
                if let Some((prev_total, prev_idle)) = self.last_cpu {
                    let d_total = total.saturating_sub(prev_total) as f64;
                    let d_idle = idle.saturating_sub(prev_idle) as f64;
                    if d_total > 0.0 {
                        snap.cpu_percent = (((d_total - d_idle) / d_total) * 100.0) as f32;
                    }
                }
                self.last_cpu = Some((total, idle));
            }
        }

        if let Ok(text) = self.read("net/dev") {
            let counters = parse::parse_net_dev(&text);
            snap.net_rx = counters.0;
            snap.net_tx = counters.1;
            if let Some((prev_rx, prev_tx)) = self.last_net {
                if elapsed > 0.0 {
                    self.last_rates.net_rx =
                        counters.0.saturating_sub(prev_rx) as f64 / elapsed;
                    self.last_rates.net_tx =
                        counters.1.saturating_sub(prev_tx) as f64 / elapsed;
                }
            }
            self.last_net = Some(counters);
        }

        if let Ok(text) = self.read("diskstats") {
            let counters = parse::parse_diskstats(&text);
            snap.disk_read = counters.0;
            snap.disk_write = counters.1;
            if let Some((prev_r, prev_w)) = self.last_disk {
                if elapsed > 0.0 {
                    // diskstats cuenta sectores de 512 bytes.
                    self.last_rates.disk_read =
                        counters.0.saturating_sub(prev_r) as f64 * 512.0 / elapsed;
                    self.last_rates.disk_write =
                        counters.1.saturating_sub(prev_w) as f64 * 512.0 / elapsed;
                }
            }
            self.last_disk = Some(counters);
        }

        let mut new_ticks = HashMap::new();
        let mut processes = Vec::new();
        if let Ok(entries) = fs::read_dir(&self.root) {
            for entry in entries.flatten() {
                let name = entry.file_name();
                let pid: i32 = match name.to_string_lossy().parse() {
                    Ok(pid) => pid,
                    Err(_) => continue,
                };
                if let Some(row) = self.read_process(pid, elapsed, &mut new_ticks) {
                    processes.push(row);
                }
            }
        }
        self.last_proc_ticks = new_ticks;
        self.last_instant = Some(now);

        snap.total_threads = processes.iter().map(|p| p.threads as u64).sum();
        // Mayor consumo primero: es el orden inicial del prototipo.
        processes.sort_by(|a, b| {
            b.cpu
                .partial_cmp(&a.cpu)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| a.pid.cmp(&b.pid))
        });
        snap.processes = processes;
        snap
    }

    fn read_process(
        &mut self,
        pid: i32,
        elapsed: f64,
        new_ticks: &mut HashMap<i32, (u64, u64)>,
    ) -> Option<ProcRow> {
        let stat = parse::parse_stat(&self.read(&format!("{pid}/stat")).ok()?)?;
        let status = self.read(&format!("{pid}/status")).unwrap_or_default();
        let uid = parse::parse_status_uid(&status).unwrap_or(0);

        let cmdline = self
            .read_bytes(&format!("{pid}/cmdline"))
            .map(|b| parse::parse_cmdline(&b))
            .unwrap_or_default();

        // Nombre visible: argv[0] recortado si es una ruta; si es una app
        // instalada se usa el nombre del lanzador, que es el que ve el usuario.
        let binario = if cmdline.is_empty() {
            stat.comm.clone()
        } else {
            let first = cmdline.split(' ').next().unwrap_or("");
            Path::new(first)
                .file_name()
                .and_then(|n| n.to_str())
                .filter(|n| !n.is_empty())
                .unwrap_or(&stat.comm)
                .to_string()
        };
        let name = self
            .desktops
            .name_for(&binario)
            .map(|n| n.to_string())
            .unwrap_or_else(|| binario.clone());

        // RSS del status si está disponible; si no, páginas × tamaño de página.
        let rss = parse::parse_status_rss_kb(&status)
            .map(|kb| kb * 1024)
            .unwrap_or_else(|| stat.rss_pages.saturating_mul(page_size()));

        let io = self
            .read(&format!("{pid}/io"))
            .map(|t| parse::parse_io(&t))
            .unwrap_or_default();

        let cpu = if elapsed > 0.0 {
            match self.last_proc_ticks.get(&pid) {
                Some((prev_ticks, _)) => {
                    let delta = stat.ticks.saturating_sub(*prev_ticks) as f64;
                    let hz = clock_ticks() as f64;
                    let cores = self.cores.max(1) as f64;
                    ((delta / hz) / elapsed * 100.0 / cores) as f32
                }
                None => 0.0,
            }
        } else {
            0.0
        };
        new_ticks.insert(pid, (stat.ticks, stat.starttime));

        let user = self.user_cache.name(uid).to_string();
        // Los hilos del kernel no tienen ejecutable asociado: el icono genérico
        // en cada fila sería ruido, así que se deja sin icono.
        let icon = if cmdline.is_empty() {
            None
        } else {
            self.resolve_icon(&binario, &cmdline)
        };

        let uptime_secs = if stat.starttime > 0 {
            let hz = clock_ticks() as f64;
            let started = stat.starttime as f64 / hz;
            (self.uptime_now() - started).max(0.0) as u64
        } else {
            0
        };

        Some(ProcRow {
            pid,
            ppid: stat.ppid,
            name,
            command: cmdline,
            user,
            uid,
            cpu: cpu.clamp(0.0, 100.0),
            rss,
            swap_kb: parse::parse_status_swap_kb(&status).unwrap_or(0),
            state: ProcState::from_char(stat.state),
            threads: stat.threads,
            priority: stat.priority,
            nice: stat.nice,
            icon,
            io,
            uptime_secs,
        })
    }

    fn uptime_now(&self) -> f64 {
        self.read("uptime")
            .ok()
            .map(|t| parse::parse_uptime(&t))
            .unwrap_or(0.0)
    }

    /// Resuelve el icono real del proceso contra el tema instalado.
    ///
    /// Prioridad: nombre declarado en el `.desktop` de ese ejecutable, nombre
    /// del propio proceso (muchas apps se llaman igual que su icono) y, como
    /// último recurso, el icono genérico de ejecutable del tema. **Nunca** se
    /// inventa un icono: si el tema no tiene ninguno, se devuelve `None` y la UI
    /// muestra la inicial.
    fn resolve_icon(&self, executable: &str, cmdline: &str) -> Option<String> {
        // 1. Nombre de icono declarado por el lanzador .desktop del ejecutable.
        if let Some(icon) = self.desktops.icon_for(executable) {
            if self.icons.path(icon).is_some() {
                return Some(icon.to_string());
            }
        }
        // 2. El propio nombre del binario: muchas apps lo usan como icono.
        if self.icons.path(executable).is_some() {
            return Some(executable.to_string());
        }
        // 3. argv[0] sin extensión (p. ej. `code-insiders` → `code`).
        if let Some(stem) = Path::new(cmdline.split(' ').next().unwrap_or(""))
            .file_stem()
            .and_then(|s| s.to_str())
        {
            if stem != executable && self.icons.path(stem).is_some() {
                return Some(stem.to_string());
            }
        }
        // 4. Icono genérico real del tema para binarios sin entrada propia.
        for generic in [
            "application-x-executable",
            "application-x-executable-symbolic",
        ] {
            if self.icons.path(generic).is_some() {
                return Some(generic.to_string());
            }
        }
        None
    }

    pub fn icon_path(&self, name: &str) -> Option<&Path> {
        self.icons.path(name)
    }

    pub fn icon_count(&self) -> usize {
        self.icons.len()
    }
}

impl Default for Sampler {
    fn default() -> Self {
        Self::new()
    }
}

fn num_cores() -> usize {
    // available_parallelism respeta afinidad y cgroups: es el número de núcleos
    // que este proceso puede usar de verdad.
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(1)
}

fn default_desktop_dirs() -> Vec<PathBuf> {
    vec![
        PathBuf::from("/usr/share/applications"),
        PathBuf::from("/usr/local/share/applications"),
    ]
}

extern "C" {
    fn sysconf(name: i32) -> i64;
}

const SC_CLK_TCK: i32 = 2;
const SC_PAGESIZE: i32 = 30;

/// Ticks de reloj por segundo (`sysconf(_SC_CLK_TCK)`), normalmente 100.
pub fn clock_ticks() -> u64 {
    // SAFETY: sysconf es pura y segura de llamar con estas constantes.
    let v = unsafe { sysconf(SC_CLK_TCK) };
    if v > 0 {
        v as u64
    } else {
        100
    }
}

/// Tamaño de página en bytes (`sysconf(_SC_PAGESIZE)`).
pub fn page_size() -> u64 {
    // SAFETY: idem.
    let v = unsafe { sysconf(SC_PAGESIZE) };
    if v > 0 {
        v as u64
    } else {
        4096
    }
}

/// Espera mínima entre muestras para que el delta de CPU tenga sentido.
pub const MIN_SAMPLE_INTERVAL: Duration = Duration::from_millis(400);

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn etiquetas_de_estado_coinciden_con_el_prototipo() {
        assert_eq!(ProcState::Running.label(), "Ejecutando");
        assert_eq!(ProcState::Sleeping.label(), "Suspendido");
        assert_eq!(ProcState::Stopped.label(), "Detenido");
        assert_eq!(ProcState::Zombie.label(), "Zombi");
    }

    #[test]
    fn mapea_las_letras_del_kernel() {
        assert_eq!(ProcState::from_char('R'), ProcState::Running);
        assert_eq!(ProcState::from_char('S'), ProcState::Sleeping);
        assert_eq!(ProcState::from_char('D'), ProcState::DiskWait);
        assert_eq!(ProcState::from_char('Z'), ProcState::Zombie);
        assert_eq!(ProcState::from_char('t'), ProcState::Stopped);
        assert_eq!(ProcState::from_char('?'), ProcState::Unknown);
    }

    #[test]
    fn el_reloj_y_la_pagina_son_positivos() {
        assert!(clock_ticks() >= 1);
        assert!(page_size() >= 512);
    }

    #[test]
    fn dos_muestras_del_proc_real_producen_datos() {
        let mut sampler = Sampler::new();
        let first = sampler.sample();
        assert!(!first.processes.is_empty(), "debe haber procesos reales");
        assert!(first.mem.total_kb > 0, "MemTotal real");
        assert!(first.cores >= 1);

        std::thread::sleep(Duration::from_millis(220));
        let second = sampler.sample();
        assert!(!second.processes.is_empty());
        // El proceso de test vive en la muestra y tiene nombre real.
        let me = std::process::id() as i32;
        let row = second.processes.iter().find(|p| p.pid == me);
        assert!(row.is_some(), "el propio proceso debe aparecer");
        let row = row.unwrap();
        assert!(!row.name.is_empty());
        assert!(row.threads >= 1);
        assert!(row.rss > 0, "RSS real del proceso");
    }

    #[test]
    fn el_total_de_cpu_queda_en_rango() {
        let mut sampler = Sampler::new();
        let _ = sampler.sample();
        std::thread::sleep(Duration::from_millis(220));
        let snap = sampler.sample();
        assert!(
            (0.0..=100.0).contains(&snap.cpu_percent),
            "CPU total entre 0 y 100, fue {}",
            snap.cpu_percent
        );
    }

    #[test]
    fn las_tasas_no_son_negativas() {
        let mut sampler = Sampler::new();
        let _ = sampler.sample();
        std::thread::sleep(Duration::from_millis(220));
        let _ = sampler.sample();
        let rates = sampler.rates();
        assert!(rates.net_rx >= 0.0);
        assert!(rates.disk_read >= 0.0);
    }

    #[test]
    fn el_indice_de_iconos_encuentra_iconos_del_tema() {
        let sampler = Sampler::new();
        // El host puede no tener /usr/share/icons; se valida solo si existe.
        if Path::new("/usr/share/icons").is_dir() {
            assert!(sampler.icon_count() > 0, "debe indexar iconos del sistema");
            let _ = sampler.icon_path("utilities-system-monitor");
        }
    }
}
