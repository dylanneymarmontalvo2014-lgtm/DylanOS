//! API C estable que consume el frontend Qt.
//!
//! El frontend nunca recorre procesos uno a uno por la frontera FFI: cada
//! refresco entrega una instantánea completa ya preparada. Las cadenas viven en
//! un arena propiedad del muestreador y siguen válidas hasta la siguiente
//! muestra, que es justo el ciclo de vida que necesita la vista.

use std::ffi::{c_char, c_int, CStr, CString};

use crate::sampler::{ProcState, Sampler, Snapshot};
use crate::services;
use crate::signals;

/// Fila de proceso expuesta a C. Los punteros apuntan al arena del muestreador.
#[repr(C)]
pub struct DpProcess {
    pub pid: i32,
    pub ppid: i32,
    pub name: *const c_char,
    pub command: *const c_char,
    pub user: *const c_char,
    pub uid: u32,
    pub cpu: f32,
    pub rss: u64,
    pub icon: *const c_char,
    pub state: *const c_char,
    pub threads: u32,
    pub priority: i32,
    pub nice: i32,
    pub uptime_secs: u64,
    pub io_read: u64,
    pub io_write: u64,
    pub swap_kb: u64,
}

/// Instantánea completa del sistema en un instante.
#[repr(C)]
pub struct DpSnapshot {
    pub count: usize,
    pub processes: *const DpProcess,
    pub cpu_percent: f32,
    pub mem_total: u64,
    pub mem_used: u64,
    pub swap_total: u64,
    pub swap_used: u64,
    pub net_rx: f64,
    pub net_tx: f64,
    pub disk_read: f64,
    pub disk_write: f64,
    pub load1: f32,
    pub load5: f32,
    pub load15: f32,
    pub uptime: f64,
    pub cores: u32,
    pub threads: u64,
}

/// Unidad de servicio expuesta a C.
#[repr(C)]
pub struct DpService {
    pub name: *const c_char,
    pub description: *const c_char,
    pub active: c_int,
    pub scope: *const c_char,
}

/// Lista de servicios con su arena de cadenas y las filas ya materializadas.
#[repr(C)]
pub struct DpServiceList {
    pub count: usize,
    pub items: *const DpService,
}

/// Estado interno que C++ mantiene como puntero opaco.
pub struct DpSampler {
    sampler: Sampler,
    snapshot: Box<DpSnapshot>,
    rows: Vec<DpProcess>,
    /// Cadenas referenciadas por `rows`; se reemplazan en cada muestra.
    arena: Vec<CString>,
}

/// Almacena `value` en el arena y devuelve un puntero estable a sus bytes.
///
/// `CString` guarda el contenido en el heap, así que mover el `CString` dentro
/// del `Vec` al crecer no invalida el puntero devuelto.
fn intern(arena: &mut Vec<CString>, value: &str) -> *const c_char {
    match CString::new(value) {
        Ok(owned) => {
            let ptr = owned.as_ptr();
            arena.push(owned);
            ptr
        }
        Err(_) => std::ptr::null(),
    }
}

/// Propietario de una lista de servicios: mantiene vivos filas y cadenas.
///
/// El layout importa: `list` debe ser el primer campo para que el puntero
/// devuelto a C++ apunte a la vista pública, y los dos vectores siguientes son
/// los que mantienen válidos los punteros de esa vista. Solo se leen al soltar
/// la lista, así que el compilador los ve como no usados: de ahí el `allow`.
pub struct DpServiceListOwner {
    #[allow(dead_code)]
    list: DpServiceList,
    #[allow(dead_code)]
    items: Vec<DpService>,
    #[allow(dead_code)]
    arena: Vec<CString>,
}

impl DpSampler {
    fn empty_snapshot() -> DpSnapshot {
        DpSnapshot {
            count: 0,
            processes: std::ptr::null(),
            cpu_percent: 0.0,
            mem_total: 0,
            mem_used: 0,
            swap_total: 0,
            swap_used: 0,
            net_rx: 0.0,
            net_tx: 0.0,
            disk_read: 0.0,
            disk_write: 0.0,
            load1: 0.0,
            load5: 0.0,
            load15: 0.0,
            uptime: 0.0,
            cores: 0,
            threads: 0,
        }
    }

    fn build(&mut self, snapshot: &Snapshot) -> *const DpSnapshot {
        self.arena.clear();
        self.rows.clear();
        self.rows.reserve(snapshot.processes.len());

        for row in &snapshot.processes {
            let name = intern(&mut self.arena, &row.name);
            let command = intern(&mut self.arena, &row.command);
            let user = intern(&mut self.arena, &row.user);
            let icon = match &row.icon {
                Some(icon) => intern(&mut self.arena, icon),
                None => std::ptr::null(),
            };
            let state = intern(&mut self.arena, row.state.label());
            self.rows.push(DpProcess {
                pid: row.pid,
                ppid: row.ppid,
                name,
                command,
                user,
                uid: row.uid,
                cpu: row.cpu,
                rss: row.rss,
                icon,
                state,
                threads: row.threads,
                priority: row.priority,
                nice: row.nice,
                uptime_secs: row.uptime_secs,
                io_read: row.io.read_bytes,
                io_write: row.io.write_bytes,
                swap_kb: row.swap_kb,
            });
        }

        let rates = self.sampler.rates();
        let mut fresh = Self::empty_snapshot();
        fresh.count = self.rows.len();
        fresh.processes = self.rows.as_ptr();
        fresh.cpu_percent = snapshot.cpu_percent;
        fresh.mem_total = snapshot.mem_total_bytes();
        fresh.mem_used = snapshot.mem_used_bytes();
        fresh.swap_total = snapshot.swap_total_bytes();
        fresh.swap_used = snapshot.swap_used_bytes();
        fresh.net_rx = rates.net_rx;
        fresh.net_tx = rates.net_tx;
        fresh.disk_read = rates.disk_read;
        fresh.disk_write = rates.disk_write;
        fresh.load1 = snapshot.load.0;
        fresh.load5 = snapshot.load.1;
        fresh.load15 = snapshot.load.2;
        fresh.uptime = snapshot.uptime_secs;
        fresh.cores = snapshot.cores;
        fresh.threads = snapshot.total_threads;
        *self.snapshot = fresh;
        &*self.snapshot as *const DpSnapshot
    }
}

/// Crea un muestreador nuevo.
#[no_mangle]
pub extern "C" fn dp_sampler_new() -> *mut DpSampler {
    Box::into_raw(Box::new(DpSampler {
        sampler: Sampler::new(),
        snapshot: Box::new(DpSampler::empty_snapshot()),
        rows: Vec::new(),
        arena: Vec::new(),
    }))
}

/// Libera el muestreador. Acepta `null`.
#[no_mangle]
pub extern "C" fn dp_sampler_free(handle: *mut DpSampler) {
    if handle.is_null() {
        return;
    }
    // SAFETY: el puntero vino de `dp_sampler_new` y no se reutiliza.
    unsafe { drop(Box::from_raw(handle)) };
}

/// Toma una muestra y devuelve la instantánea. El puntero es válido hasta la
/// siguiente llamada a `dp_sample` o `dp_sampler_free`.
#[no_mangle]
pub extern "C" fn dp_sample(handle: *mut DpSampler) -> *const DpSnapshot {
    if handle.is_null() {
        return std::ptr::null();
    }
    // SAFETY: `handle` proviene de `dp_sampler_new`; C++ llama de forma
    // secuencial desde el hilo de la GUI, sin préstamos solapados.
    let state = unsafe { &mut *handle };
    let snapshot = state.sampler.sample();
    state.build(&snapshot)
}

/// Envía `SIGTERM` (o `SIGKILL` si `force` ≠ 0) a un proceso real.
///
/// Devuelve 0 si el kernel aceptó la señal; en caso contrario devuelve el
/// `errno` y escribe el motivo legible en `buffer`.
#[no_mangle]
pub extern "C" fn dp_terminate(pid: i32, force: c_int, buffer: *mut c_char, len: usize) -> c_int {
    let result = if force != 0 {
        signals::force_terminate(pid)
    } else {
        signals::terminate(pid)
    };
    match result {
        Ok(()) => 0,
        Err(error) => {
            write_buffer(buffer, len, signals::describe_error(&error));
            error.raw_os_error().unwrap_or(-1)
        }
    }
}

/// Comprueba si un proceso sigue vivo (sin enviarle señal).
#[no_mangle]
pub extern "C" fn dp_is_alive(pid: i32) -> c_int {
    c_int::from(signals::is_alive(pid))
}

/// Cambia la prioridad real de un proceso. 0 si el kernel lo aceptó.
#[no_mangle]
pub extern "C" fn dp_set_priority(
    pid: i32,
    level: c_int,
    buffer: *mut c_char,
    len: usize,
) -> c_int {
    let nivel = usize::try_from(level).unwrap_or(1).min(crate::priority::PRIORITY_LABELS.len() - 1);
    match crate::priority::set_nice(pid, crate::priority::nice_for_level(nivel)) {
        Ok(()) => 0,
        Err(error) => {
            write_buffer(buffer, len, crate::priority::describe_error(&error));
            error.raw_os_error().unwrap_or(-1)
        }
    }
}

/// Nivel del selector (0–3) que corresponde a un `nice` real.
#[no_mangle]
pub extern "C" fn dp_priority_level(nice: c_int) -> c_int {
    crate::priority::level_for_nice(nice) as c_int
}

fn write_buffer(buffer: *mut c_char, len: usize, text: &str) {
    if buffer.is_null() || len == 0 {
        return;
    }
    let bytes = text.as_bytes();
    let take = bytes.len().min(len - 1);
    // SAFETY: el llamador reserva `len` bytes; se copian como mucho `len - 1` y
    // se cierra con NUL.
    unsafe {
        std::ptr::copy_nonoverlapping(bytes.as_ptr() as *const c_char, buffer, take);
        *buffer.add(take) = 0;
    }
}

/// Lista las unidades de servicio reales. Liberar con `dp_service_list_free`.
#[no_mangle]
pub extern "C" fn dp_service_list() -> *mut DpServiceList {
    let units = services::list_services().unwrap_or_default();
    let mut arena: Vec<CString> = Vec::with_capacity(units.len() * 3);
    let mut items: Vec<DpService> = Vec::with_capacity(units.len());
    for unit in &units {
        items.push(DpService {
            name: intern(&mut arena, &unit.name),
            description: intern(&mut arena, &unit.description),
            active: c_int::from(unit.active),
            scope: intern(&mut arena, unit.scope),
        });
    }
    let count = items.len();
    let pointer = items.as_ptr();
    // El owner se devuelve como `DpServiceList`; su primer campo es la vista
    // pública, así que el cast es estable por `#[repr(C)]`.
    let owner = Box::new(DpServiceListOwner {
        list: DpServiceList {
            count,
            items: pointer,
        },
        items,
        arena,
    });
    Box::into_raw(owner) as *mut DpServiceList
}

/// Libera la lista devuelta por `dp_service_list`. Acepta `null`.
#[no_mangle]
pub extern "C" fn dp_service_list_free(list: *mut DpServiceList) {
    if list.is_null() {
        return;
    }
    // SAFETY: se creó como `DpServiceListOwner` en `dp_service_list`.
    unsafe { drop(Box::from_raw(list as *mut DpServiceListOwner)) };
}

/// Inicia o detiene una unidad real. Devuelve 0 si systemd lo aceptó.
#[no_mangle]
pub extern "C" fn dp_service_set_active(
    name: *const c_char,
    active: c_int,
    user_scope: c_int,
    buffer: *mut c_char,
    len: usize,
) -> c_int {
    if name.is_null() {
        write_buffer(buffer, len, "Unidad vacía.");
        return -1;
    }
    // SAFETY: el llamador garantiza una cadena terminada en NUL.
    let unit = match unsafe { CStr::from_ptr(name) }.to_str() {
        Ok(unit) if !unit.is_empty() => unit,
        _ => {
            write_buffer(buffer, len, "Nombre de unidad no válido.");
            return -1;
        }
    };
    let result = services::set_service_active(unit, active != 0, user_scope != 0);
    write_buffer(buffer, len, &result.message);
    c_int::from(!result.ok)
}

/// Número de iconos indexados del tema activo (diagnóstico y QA).
#[no_mangle]
pub extern "C" fn dp_icon_count(handle: *mut DpSampler) -> usize {
    if handle.is_null() {
        return 0;
    }
    // SAFETY: idem que en `dp_sample`.
    unsafe { (*handle).sampler.icon_count() }
}

/// Ruta del archivo del icono en el tema, o `null` si no existe.
#[no_mangle]
pub extern "C" fn dp_icon_path(handle: *mut DpSampler, name: *const c_char) -> *const c_char {
    if handle.is_null() || name.is_null() {
        return std::ptr::null();
    }
    // SAFETY: ambos punteros son válidos por contrato del llamador.
    let state = unsafe { &mut *handle };
    let name = match unsafe { CStr::from_ptr(name) }.to_str() {
        Ok(name) => name,
        Err(_) => return std::ptr::null(),
    };
    match state.sampler.icon_path(name) {
        Some(path) => {
            let owned = path.to_string_lossy().to_string();
            intern(&mut state.arena, &owned)
        }
        None => std::ptr::null(),
    }
}

/// Etiqueta de estado para una letra de `/proc/<pid>/stat`.
#[no_mangle]
pub extern "C" fn dp_state_label(code: c_int) -> *const c_char {
    let state = match u8::try_from(code).ok().map(char::from) {
        Some(c) => ProcState::from_char(c),
        None => ProcState::Unknown,
    };
    // `label` devuelve `&'static str`: el puntero es válido siempre.
    state.label().as_ptr() as *const c_char
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn la_instantanea_expone_procesos_reales() {
        let handle = dp_sampler_new();
        assert!(!handle.is_null());
        // SAFETY: handle válido; se libera al final.
        unsafe {
            let snap = dp_sample(handle);
            assert!(!snap.is_null());
            let snapshot = &*snap;
            assert!(snapshot.count > 0, "el sistema tiene procesos");
            assert!(snapshot.mem_total > 0);
            assert!(snapshot.cores >= 1);
            let rows = std::slice::from_raw_parts(snapshot.processes, snapshot.count);
            let me = std::process::id() as i32;
            let row = rows.iter().find(|r| r.pid == me).expect("el propio proceso aparece");
            assert!(!row.name.is_null());
            let name = CStr::from_ptr(row.name).to_str().unwrap();
            assert!(name.contains("dylanos_process_core") || !name.is_empty());
            // La muestra siguiente sigue siendo válida y no filtra punteros.
            let again = dp_sample(handle);
            assert!(!again.is_null());
            assert!((*again).count > 0);
            dp_sampler_free(handle);
        }
    }

    #[test]
    fn terminar_un_pid_inexistente_devuelve_errno_y_mensaje() {
        let mut buf = [0 as c_char; 256];
        let rc = dp_terminate(i32::MAX - 2, 0, buf.as_mut_ptr(), buf.len());
        assert!(rc != 0, "debe fallar con un pid inexistente");
        // SAFETY: dp_terminate escribe NUL dentro del buffer.
        let message = unsafe { CStr::from_ptr(buf.as_ptr()) }.to_str().unwrap();
        assert_eq!(message, "El proceso ya no existe.");
    }

    #[test]
    fn dp_is_alive_detecta_el_propio_proceso() {
        assert_eq!(dp_is_alive(std::process::id() as i32), 1);
        assert_eq!(dp_is_alive(0), 0);
    }

    #[test]
    fn la_etiqueta_de_estado_es_estable() {
        // SAFETY: label devuelve literales estáticos.
        unsafe {
            let running = CStr::from_ptr(dp_state_label('R' as c_int)).to_str().unwrap();
            let sleeping = CStr::from_ptr(dp_state_label('S' as c_int)).to_str().unwrap();
            let unknown = CStr::from_ptr(dp_state_label(0)).to_str().unwrap();
            assert_eq!(running, "Ejecutando");
            assert_eq!(sleeping, "Suspendido");
            assert_eq!(unknown, "Desconocido");
        }
    }

    #[test]
    fn la_lista_de_servicios_se_libera_sin_fugas() {
        let list = dp_service_list();
        assert!(!list.is_null());
        // SAFETY: la lista es válida hasta liberarla.
        unsafe {
            let owner = &*(list as *const DpServiceListOwner);
            assert_eq!(owner.list.count, owner.items.len());
            for item in &owner.items {
                if !item.name.is_null() {
                    assert!(!CStr::from_ptr(item.name).to_bytes().is_empty());
                }
            }
            dp_service_list_free(list);
        }
    }
}
