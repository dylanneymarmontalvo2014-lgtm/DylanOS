//! Sonda de línea de comandos: imprime una instantánea real del sistema.
//!
//! Sirve para QA sin abrir ventana (y para comparar contra `top`/`free`), así
//! que no depende de Qt ni del entorno gráfico.

use std::time::Duration;

use dylanos_process_core::{format_bytes, format_memory, format_percent, Sampler};

fn main() {
    let mut sampler = Sampler::new();
    // La primera muestra no tiene delta de CPU: se toma una base y se espera el
    // intervalo mínimo para que el porcentaje tenga sentido.
    let _ = sampler.sample();
    std::thread::sleep(Duration::from_millis(600));
    let snapshot = sampler.sample();
    let rates = sampler.rates();

    println!("núcleos: {}", snapshot.cores);
    println!("cpu: {}", format_percent(snapshot.cpu_percent));
    println!(
        "memoria: {} / {}",
        format_memory(snapshot.mem_used_bytes()),
        format_memory(snapshot.mem_total_bytes())
    );
    println!(
        "swap: {} / {}",
        format_memory(snapshot.swap_used_bytes()),
        format_memory(snapshot.swap_total_bytes())
    );
    println!(
        "red: {:.0} B/s rx · {:.0} B/s tx",
        rates.net_rx, rates.net_tx
    );
    println!(
        "disco: {:.0} B/s lectura · {:.0} B/s escritura",
        rates.disk_read, rates.disk_write
    );
    println!(
        "carga: {:.2} {:.2} {:.2}",
        snapshot.load.0, snapshot.load.1, snapshot.load.2
    );
    println!("procesos: {}", snapshot.processes.len());
    println!("hilos: {}", snapshot.total_threads);
    println!();
    println!(
        "{:>7}  {:>22}  {:>10}  {:>7}  {:>6}  {:<14}  ICONO",
        "PID", "NOMBRE", "USUARIO", "CPU", "HILOS", "ESTADO"
    );
    for row in snapshot.processes.iter().take(15) {
        println!(
            "{:>7}  {:>22}  {:>10}  {:>6.1}%  {:>6}  {:<14}  {}",
            row.pid,
            truncate(&row.name, 22),
            row.user,
            row.cpu,
            row.threads,
            row.state.label(),
            match &row.icon {
                Some(icon) => match sampler.icon_path(icon) {
                    Some(path) => path.display().to_string(),
                    None => format!("{icon} (sin archivo)"),
                },
                None => "—".to_string(),
            }
        );
    }
    println!();
    println!(
        "iconos indexados en el tema: {}",
        sampler.icon_count()
    );
    println!(
        "rss del proceso mayor: {}",
        snapshot
            .processes
            .first()
            .map(|p| format_bytes(p.rss))
            .unwrap_or_else(|| "—".to_string())
    );
}

fn truncate(value: &str, max: usize) -> String {
    let chars: Vec<char> = value.chars().collect();
    if chars.len() <= max {
        return value.to_string();
    }
    let mut out: String = chars.into_iter().take(max.saturating_sub(1)).collect();
    out.push('…');
    out
}
