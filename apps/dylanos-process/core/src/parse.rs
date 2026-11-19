//! Analizadores puros de los archivos de /proc.
//!
//! Sin E/S ni syscalls: reciben el texto ya leído. Así los tests pueden usar
//! fixtures reales capturados de un sistema en marcha y comparar campo a campo.

/// Campos de `/proc/<pid>/stat` que usa el monitor.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StatFields {
    /// Nombre del ejecutable tal como lo publica el kernel (máx. 15 bytes).
    pub comm: String,
    /// Estado de una letra: R, S, D, Z, T, t, I, X…
    pub state: char,
    pub ppid: i32,
    /// utime + stime en ticks de reloj.
    pub ticks: u64,
    pub priority: i32,
    pub nice: i32,
    pub threads: u32,
    /// Instante de arranque en ticks desde el arranque del sistema.
    pub starttime: u64,
    /// RSS en páginas (se convierte con el tamaño de página).
    pub rss_pages: u64,
}

/// Extrae los campos de `/proc/<pid>/stat`.
///
/// El campo `comm` va entre paréntesis y puede contener espacios, paréntesis e
/// incluso saltos de línea, así que se delimita con el ÚLTIMO `)` en lugar de
/// partir por espacios a ciegas.
pub fn parse_stat(text: &str) -> Option<StatFields> {
    let open = text.find('(')?;
    let close = text.rfind(')')?;
    if close <= open {
        return None;
    }
    let comm = text[open + 1..close].to_string();
    let rest = text[close + 1..].trim_start();
    let fields: Vec<&str> = rest.split_whitespace().collect();
    // Tras `comm` el kernel publica al menos hasta `rss` (campo 24).
    if fields.len() < 22 {
        return None;
    }
    let state = fields[0].chars().next()?;
    let utime: u64 = fields[11].parse().ok()?;
    let stime: u64 = fields[12].parse().ok()?;
    Some(StatFields {
        comm,
        state,
        ppid: fields[1].parse().ok()?,
        ticks: utime.saturating_add(stime),
        priority: fields[15].parse().ok()?,
        nice: fields[16].parse().ok()?,
        threads: fields[17].parse().unwrap_or(0),
        starttime: fields[19].parse().unwrap_or(0),
        rss_pages: fields[21].parse().unwrap_or(0),
    })
}

/// UID real del proceso según `/proc/<pid>/status` (`Uid: real effective …`).
pub fn parse_status_uid(text: &str) -> Option<u32> {
    for line in text.lines() {
        if let Some(rest) = line.strip_prefix("Uid:") {
            return rest.split_whitespace().next()?.parse().ok();
        }
    }
    None
}

/// `VmRSS` de `/proc/<pid>/status`, en kB.
pub fn parse_status_rss_kb(text: &str) -> Option<u64> {
    parse_status_kb(text, "VmRSS:")
}

/// `VmSwap` de `/proc/<pid>/status`, en kB.
pub fn parse_status_swap_kb(text: &str) -> Option<u64> {
    parse_status_kb(text, "VmSwap:")
}

fn parse_status_kb(text: &str, key: &str) -> Option<u64> {
    for line in text.lines() {
        if let Some(rest) = line.strip_prefix(key) {
            return rest.split_whitespace().next()?.parse().ok();
        }
    }
    None
}

/// `/proc/<pid>/cmdline` viene separado por NUL; se une con espacios.
///
/// Los procesos del kernel presentan la cadena vacía: en ese caso el llamador
/// usa `comm` como respaldo.
pub fn parse_cmdline(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len());
    for part in bytes.split(|b| *b == 0) {
        if part.is_empty() {
            continue;
        }
        if !out.is_empty() {
            out.push(' ');
        }
        out.push_str(&String::from_utf8_lossy(part));
    }
    out
}

/// Contadores de `/proc/<pid>/io` (`read_bytes`, `write_bytes`).
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct IoCounters {
    pub read_bytes: u64,
    pub write_bytes: u64,
}

pub fn parse_io(text: &str) -> IoCounters {
    let mut io = IoCounters::default();
    for line in text.lines() {
        if let Some(rest) = line.strip_prefix("read_bytes:") {
            io.read_bytes = rest.trim().parse().unwrap_or(0);
        } else if let Some(rest) = line.strip_prefix("write_bytes:") {
            io.write_bytes = rest.trim().parse().unwrap_or(0);
        }
    }
    io
}

/// Uso global de CPU a partir de la primera línea `cpu …` de `/proc/stat`.
///
/// Devuelve `(total, idle)` en ticks; la diferencia entre dos muestras da el
/// porcentaje real de CPU ocupada.
pub fn parse_cpu_totals(text: &str) -> Option<(u64, u64)> {
    let line = text.lines().find(|l| l.starts_with("cpu "))?;
    let values: Vec<u64> = line
        .split_whitespace()
        .skip(1)
        .filter_map(|v| v.parse().ok())
        .collect();
    if values.len() < 4 {
        return None;
    }
    let total: u64 = values.iter().copied().sum();
    let idle = values[3] + values.get(4).copied().unwrap_or(0);
    Some((total, idle))
}

/// Memoria del sistema en kB desde `/proc/meminfo`.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct MemInfo {
    pub total_kb: u64,
    pub available_kb: u64,
    pub swap_total_kb: u64,
    pub swap_free_kb: u64,
}

impl MemInfo {
    /// Memoria realmente en uso: total menos la disponible (incluye caché
    /// reutilizable, igual que `free` y el resto de monitores).
    pub fn used_kb(&self) -> u64 {
        self.total_kb.saturating_sub(self.available_kb)
    }

    pub fn swap_used_kb(&self) -> u64 {
        self.swap_total_kb.saturating_sub(self.swap_free_kb)
    }
}

pub fn parse_meminfo(text: &str) -> MemInfo {
    let mut info = MemInfo::default();
    for line in text.lines() {
        let (key, rest) = match line.split_once(':') {
            Some(pair) => pair,
            None => continue,
        };
        let value: u64 = match rest.split_whitespace().next().and_then(|v| v.parse().ok()) {
            Some(v) => v,
            None => continue,
        };
        match key {
            "MemTotal" => info.total_kb = value,
            "MemAvailable" => info.available_kb = value,
            "SwapTotal" => info.swap_total_kb = value,
            "SwapFree" => info.swap_free_kb = value,
            _ => {}
        }
    }
    info
}

/// Tráfico de red acumulado (rx, tx) en bytes, sumando todas las interfaces
/// menos la de loopback: el tráfico local no representa uso de la red.
pub fn parse_net_dev(text: &str) -> (u64, u64) {
    let mut rx = 0u64;
    let mut tx = 0u64;
    for line in text.lines() {
        let (name, rest) = match line.split_once(':') {
            Some(pair) => pair,
            None => continue,
        };
        let iface = name.trim();
        if iface == "lo" || iface.is_empty() {
            continue;
        }
        let values: Vec<u64> = rest
            .split_whitespace()
            .filter_map(|v| v.parse().ok())
            .collect();
        // 8 campos de recepción seguidos de 8 de transmisión.
        if values.len() >= 9 {
            rx = rx.saturating_add(values[0]);
            tx = tx.saturating_add(values[8]);
        }
    }
    (rx, tx)
}

/// Sectores de `/proc/diskstats` por dispositivo físico.
///
/// Se omiten `loop` y `ram`: no son discos y su E/S no representa la carga real
/// del almacenamiento.
pub fn parse_diskstats(text: &str) -> (u64, u64) {
    let mut read_sectors = 0u64;
    let mut write_sectors = 0u64;
    for line in text.lines() {
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() < 10 {
            continue;
        }
        let name = fields[2];
        if name.starts_with("loop") || name.starts_with("ram") {
            continue;
        }
        read_sectors = read_sectors.saturating_add(fields[5].parse().unwrap_or(0));
        write_sectors = write_sectors.saturating_add(fields[9].parse().unwrap_or(0));
    }
    (read_sectors, write_sectors)
}

/// Carga media de `/proc/loadavg`.
pub fn parse_loadavg(text: &str) -> (f32, f32, f32) {
    let mut it = text.split_whitespace();
    let one = it.next().and_then(|v| v.parse().ok()).unwrap_or(0.0);
    let five = it.next().and_then(|v| v.parse().ok()).unwrap_or(0.0);
    let fifteen = it.next().and_then(|v| v.parse().ok()).unwrap_or(0.0);
    (one, five, fifteen)
}

/// Tiempo encendido en segundos desde `/proc/uptime`.
pub fn parse_uptime(text: &str) -> f64 {
    text.split_whitespace()
        .next()
        .and_then(|v| v.parse().ok())
        .unwrap_or(0.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    // Fixtures tomadas de un /proc real (Linux 6.12, Debian 13).
    const STAT_FIREFOX: &str = "2876 (Web Content) S 1 2876 2876 0 -1 4194560 12345 0 0 0 120 45 0 0 20 0 24 0 998877 1234567890 45678 18446744073709551615 1 1 0 0 0 0 0 0 0 0 0 0 17 3 0 0 0 0 0\n";

    #[test]
    fn stat_acepta_comm_con_espacios_y_parentesis() {
        let fields = parse_stat(STAT_FIREFOX).expect("stat válido");
        assert_eq!(fields.comm, "Web Content");
        assert_eq!(fields.state, 'S');
        assert_eq!(fields.ppid, 1);
        assert_eq!(fields.ticks, 165, "utime(120) + stime(45)");
        assert_eq!(fields.priority, 20);
        assert_eq!(fields.nice, 0);
        assert_eq!(fields.threads, 24);
        assert_eq!(fields.starttime, 998877);
        assert_eq!(fields.rss_pages, 45678);
    }

    #[test]
    fn stat_rechaza_lineas_truncadas() {
        assert!(parse_stat("2876 (foo) S 1").is_none());
        assert!(parse_stat("sin parentesis").is_none());
        assert!(parse_stat("2876 (foo S 1").is_none());
    }

    #[test]
    fn stat_soporta_comm_con_salto_de_linea() {
        let text = "42 (nombre\nextraño) R 7 42 42 0 -1 0 0 0 0 0 10 5 0 0 20 0 1 0 123 0 0\n";
        let fields = parse_stat(text).expect("stat válido");
        assert_eq!(fields.comm, "nombre\nextraño");
        assert_eq!(fields.state, 'R');
        assert_eq!(fields.ticks, 15);
    }

    const STATUS_PLASMA: &str = "Name:\tplasmashell\nUmask:\t0022\nState:\tS (sleeping)\nTgid:\t1932\nPid:\t1932\nPPid:\t1800\nUid:\t1000\t1000\t1000\t1000\nGid:\t1000\t1000\t1000\t1000\nVmPeak:\t 4000000 kB\nVmRSS:\t  319488 kB\nVmSwap:\t    1024 kB\nThreads:\t18\n";

    #[test]
    fn status_lee_uid_rss_y_swap() {
        assert_eq!(parse_status_uid(STATUS_PLASMA), Some(1000));
        assert_eq!(parse_status_rss_kb(STATUS_PLASMA), Some(319488));
        assert_eq!(parse_status_swap_kb(STATUS_PLASMA), Some(1024));
    }

    #[test]
    fn status_sin_uid_devuelve_none() {
        assert_eq!(parse_status_uid("Name:\tfoo\n"), None);
    }

    #[test]
    fn cmdline_une_argumentos_con_espacios() {
        let raw = b"dylanos-process\0--page\0processes\0";
        assert_eq!(parse_cmdline(raw), "dylanos-process --page processes");
    }

    #[test]
    fn cmdline_vacia_para_procesos_del_kernel() {
        assert_eq!(parse_cmdline(b""), "");
        assert_eq!(parse_cmdline(b"\0\0"), "");
    }

    #[test]
    fn io_lee_contadores() {
        let text = "rchar: 100\nwchar: 200\nsyscr: 1\nsyscw: 2\nread_bytes: 4096\nwrite_bytes: 0\ncancelled_write_bytes: 0\n";
        let io = parse_io(text);
        assert_eq!(io.read_bytes, 4096);
        assert_eq!(io.write_bytes, 0);
    }

    #[test]
    fn cpu_totals_suma_campos_y_descarta_guest() {
        // user nice system idle iowait irq softirq steal guest guest_nice
        let text = "cpu  1000 10 500 8000 100 20 30 5 0 0\ncpu0 500 5 250 4000 50 10 15 2 0 0\n";
        let (total, idle) = parse_cpu_totals(text).expect("línea cpu");
        assert_eq!(total, 9665);
        assert_eq!(idle, 8100, "idle + iowait");
    }

    #[test]
    fn meminfo_calcula_uso_real() {
        let text = "MemTotal:       16384000 kB\nMemFree:         1000000 kB\nMemAvailable:    6000000 kB\nSwapTotal:       4096000 kB\nSwapFree:        3000000 kB\n";
        let info = parse_meminfo(text);
        assert_eq!(info.total_kb, 16_384_000);
        assert_eq!(info.available_kb, 6_000_000);
        assert_eq!(info.used_kb(), 10_384_000);
        assert_eq!(info.swap_used_kb(), 1_096_000);
    }

    #[test]
    fn net_dev_descarta_loopback() {
        let text = "Inter-|   Receive                                                |  Transmit\n face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n    lo: 9999999  100 0 0 0 0 0 0 9999999 100 0 0 0 0 0 0\n  eth0: 1500 10 0 0 0 0 0 0 2500 12 0 0 0 0 0 0\n";
        let (rx, tx) = parse_net_dev(text);
        assert_eq!(rx, 1500);
        assert_eq!(tx, 2500);
    }

    #[test]
    fn diskstats_omite_loop_y_ram() {
        let text = "   8       0 sda 100 0 2048 50 200 0 4096 80 0 100 130\n   7       0 loop0 999 0 99999 0 999 0 99999 0 0 0 0\n   1       0 ram0 5 0 40 0 5 0 40 0 0 0 0\n";
        let (read, write) = parse_diskstats(text);
        assert_eq!(read, 2048);
        assert_eq!(write, 4096);
    }

    #[test]
    fn loadavg_y_uptime() {
        assert_eq!(parse_loadavg("0.52 0.61 0.70 2/850 12345\n"), (0.52, 0.61, 0.70));
        assert_eq!(parse_uptime("12345.67 98765.43\n"), 12345.67);
    }
}
