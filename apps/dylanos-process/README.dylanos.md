# DylanOS Process

Monitor de procesos y recursos de DylanOS. El núcleo de datos está escrito en
**Rust** y la interfaz en **Qt 6 / QML**; ninguna cifra de la ventana es
simulada: todo sale de `/proc`, del tema de iconos del sistema y de systemd.

## Por qué un núcleo en Rust

El monitor anterior era el fork de `plasma-systemmonitor` con los modelos de
KSysGuard. Esa pila obliga a arrastrar `libksysguard`, `ksystemstats` y los
módulos QML de KDE para leer cuatro contadores. El núcleo propio lee los mismos
archivos del kernel con una fracción del coste y sin dependencias externas del
crate, así que el binario arranca sin cargar la cadena de KDE.

`plasma-systemmonitor` **sigue instalado en el ISO**: es la fuente de
`ksystemstats`/`libksysguard` que usa `plasma-desktop`, y purgarlo rompería
Plasma. Lo que cambia es que ya no es la aplicación visible: `stage.py` oculta
su lanzador y el menú abre `dylanos-process`.

## Datos reales

| Dato | Fuente |
| --- | --- |
| Procesos, estado, PPID, hilos, prioridad | `/proc/<pid>/stat` y `/proc/<pid>/status` |
| CPU por proceso | delta de `utime+stime` entre muestras, normalizado por núcleo |
| CPU total | delta de `/proc/stat` |
| Memoria y swap | `/proc/meminfo` (`MemAvailable`, no `MemFree`) |
| Memoria por proceso | `VmRSS` (con respaldo de páginas × tamaño de página) |
| E/S de disco | `/proc/<pid>/io` y `/proc/diskstats` (sin `loop` ni `ram`) |
| Red | `/proc/net/dev` (excluye `lo`) |
| Usuario | `getpwuid_r` con caché por uid |
| Icono | `.desktop` instalado → `kdeglobals` → `index.theme` del tema activo |
| Servicios | `systemctl list-units` + `start`/`stop` reales |

Cuando el kernel no permite leer algo (procesos de otro usuario, contadores
restringidos) la interfaz muestra `—` o `0 B`. Nunca rellena el hueco con un
valor inventado ni con aleatoriedad.

## Acciones

- **Finalizar proceso**: `SIGTERM` real vía `kill(2)`, siempre con confirmación.
- **Forzar finalización**: `SIGKILL` real, también con confirmación.
- **Prioridad**: `setpriority(2)` real. El kernel exige `CAP_SYS_NICE` para
  subirla; si la deniega, se muestra el motivo real (`EACCES`/`EPERM`).
- **Servicios**: `systemctl start|stop`. Polkit decide si hace falta
  autenticarse; el mensaje de systemd se muestra tal cual.

La aplicación no eleva privilegios en ningún caso.

## Compilación

El núcleo se compila con cargo y se enlaza al binario Qt:

```bash
cd apps/dylanos-process/core
cargo build --release --offline --locked   # sin dependencias externas
cd ..
cmake -S . -B build -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build --parallel 4
ctest --test-dir build --output-on-failure
sudo cmake --install build
```

`scripts/build.sh` hace exactamente esto dentro del chroot Debian 13, instala
`rustc`/`cargo` solo para compilar y los purga al final: el ISO no lleva cadena
de herramientas de Rust.

Si el núcleo ya está construido (por ejemplo en el host) se puede saltar cargo
con `-DDYLANOS_PROCESS_SKIP_CORE=ON`, que enlaza la `libcore.a` existente.

## Pruebas

```bash
# Núcleo: parsers con fixtures reales de /proc, deltas de CPU, señales reales.
cd core && cargo test --release

# Interfaz: QtQuickTest offscreen contra los modelos de producción.
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  ./build/tests/tst_process_ui -input tests/qml

# Contrato estático (sin Rust ni Qt): núcleo sin datos simulados, UI fiel al
# prototipo, integración con build/staging.
python3 -m unittest scripts.tests.test_process_ui_contract
```

Los tests de señal crean procesos reales y los terminan; los de prioridad
comprueban las dos caras del modelo de permisos del kernel (bajar prioridad
siempre se permite, subirla exige privilegios) sin elevar nada.

## Capturas de QA

```bash
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  ./build/dylanos-process --page processes --screenshot salida.png --size 1280x800
```

`--page` acepta `processes`, `performance`, `apps` y `services`. La captura es
opt-in: sin `--screenshot` la app no escribe nada. En una sesión real la ventana
es frameless con semáforos integrados, como el resto de apps DylanOS.

## Estructura

- `core/` — núcleo Rust (`dylanos-process-core`): `parse.rs` (analizadores puros
  de `/proc`), `sampler.rs` (deltas y agregados), `icons.rs` (tema real),
  `services.rs` (systemd), `signals.rs`/`priority.rs` (kernel) y `ffi.rs`
  (API C estable para Qt).
- `src/` — modelos Qt (`ProcessModel`, `ProcessFilterModel`,
  `ApplicationModel`, `ServiceModel`), controlador y proveedor de iconos.
- `qml/` — interfaz fiel al prototipo (barra de título, 4 pestañas, tarjetas,
  tabla, detalle, rendimiento, aplicaciones, servicios).
- `tests/` — QtQuickTest de la interfaz.
- `legacy/` — fork original de `plasma-systemmonitor` 6.3.6, conservado como
  referencia y por sus avisos de licencia. **No se compila.**

## Procedencia y licencia

La interfaz es nueva y sigue el prototipo de DylanOS. El árbol `legacy/`
procede de KDE `plasma-systemmonitor`, upstream
https://invent.kde.org/plasma/plasma-systemmonitor, rama `Plasma/6.3`, commit
`be4f1594995698cac59959b8baa4421f435a1015` (versión 6.3.6), y conserva sus
avisos SPDX/copyright, textos de licencia y traducciones. El código nuevo se
distribuye bajo `GPL-3.0-only`, coherente con el resto de DylanOS.
