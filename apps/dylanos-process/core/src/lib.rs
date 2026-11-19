//! Núcleo de DylanOS Process: datos reales del sistema para Qt/QML.
//!
//! Todo lo que la interfaz muestra sale de aquí, leyendo `/proc`, el tema de
//! iconos instalado y systemd. No hay generadores aleatorios ni valores de
//! ejemplo: cuando el kernel no permite leer un dato, se informa como tal.

pub mod icons;
pub mod parse;
pub mod priority;
pub mod sampler;
pub mod services;
pub mod signals;
pub mod users;

pub mod ffi;

pub use sampler::{ProcRow, ProcState, Rates, Sampler, Snapshot};
pub use priority::PRIORITY_LABELS;

/// Formatea bytes con la unidad que corresponde (B, KB, MB, GB, TB).
pub fn format_bytes(bytes: u64) -> String {
    const KB: f64 = 1024.0;
    let value = bytes as f64;
    if value < KB {
        return format!("{bytes} B");
    }
    if value < KB * KB {
        return format!("{:.1} KB", value / KB);
    }
    if value < KB * KB * KB {
        return format!("{:.1} MB", value / (KB * KB));
    }
    if value < KB * KB * KB * KB {
        return format!("{:.1} GB", value / (KB * KB * KB));
    }
    format!("{:.1} TB", value / (KB * KB * KB * KB))
}

/// Formatea una tasa en bytes por segundo, con la misma escala que `top`.
pub fn format_rate(bytes_per_second: f64) -> String {
    if bytes_per_second < 1024.0 {
        return format!("{:.0} B/s", bytes_per_second);
    }
    if bytes_per_second < 1024.0 * 1024.0 {
        return format!("{:.1} KB/s", bytes_per_second / 1024.0);
    }
    format!("{:.1} MB/s", bytes_per_second / (1024.0 * 1024.0))
}

/// Formatea un porcentaje con un decimal, como el prototipo.
pub fn format_percent(value: f32) -> String {
    format!("{value:.1} %")
}

/// Memoria en la forma del prototipo: GB con un decimal a partir de 1 GB.
pub fn format_memory(bytes: u64) -> String {
    let gb = bytes as f64 / (1024.0 * 1024.0 * 1024.0);
    if gb >= 1.0 {
        format!("{gb:.1} GB")
    } else {
        format!("{:.0} MB", bytes as f64 / (1024.0 * 1024.0))
    }
}

/// Segundos en un texto corto y estable: `3 s`, `12 min`, `4 h 3 min`, `2 d 5 h`.
pub fn format_duration(seconds: u64) -> String {
    if seconds < 60 {
        return format!("{seconds} s");
    }
    let minutes = seconds / 60;
    if minutes < 60 {
        return format!("{minutes} min");
    }
    let hours = minutes / 60;
    if hours < 24 {
        return format!("{hours} h {} min", minutes % 60);
    }
    format!("{} d {} h", hours / 24, hours % 24)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bytes_se_formatean_por_escala() {
        assert_eq!(format_bytes(512), "512 B");
        assert_eq!(format_bytes(2048), "2.0 KB");
        assert_eq!(format_bytes(5 * 1024 * 1024), "5.0 MB");
        assert_eq!(format_bytes(3 * 1024 * 1024 * 1024), "3.0 GB");
    }

    #[test]
    fn tasas_en_bytes_por_segundo() {
        assert_eq!(format_rate(500.0), "500 B/s");
        assert_eq!(format_rate(2048.0), "2.0 KB/s");
        assert_eq!(format_rate(3.0 * 1024.0 * 1024.0), "3.0 MB/s");
    }

    #[test]
    fn porcentaje_con_un_decimal() {
        assert_eq!(format_percent(12.44), "12.4 %");
    }

    #[test]
    fn memoria_como_el_prototipo() {
        assert_eq!(format_memory(3 * 1024 * 1024 * 1024), "3.0 GB");
        assert_eq!(format_memory(300 * 1024 * 1024), "300 MB");
    }

    #[test]
    fn duraciones_legibles() {
        assert_eq!(format_duration(5), "5 s");
        assert_eq!(format_duration(90), "1 min");
        assert_eq!(format_duration(3600 + 180), "1 h 3 min");
        assert_eq!(format_duration(86400 * 2 + 7200), "2 d 2 h");
    }
}
