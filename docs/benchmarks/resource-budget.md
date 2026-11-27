# Presupuesto de recursos: medición y línea base

Este documento fija los límites de la especificación Ultra de recursos, explica
cómo medirlos con datos reales y registra la primera línea base obtenida con el
arnés `scripts/benchmarks/resource_benchmark.py`. No sustituye una medición en la
ISO instalada: las cifras de aquí son de procesos nuevos en el host de
desarrollo, con renderizado `offscreen` y backend Quick por software.

## Límites

| Ámbito | RAM | CPU | GPU | Swap | Disco |
|---|---:|---:|---:|---:|---|
| Sistema en reposo (sin apps de usuario) | ≤ 300 MB | ≤ 3 % | ≤ 3 % | 0 MB ideal | casi nulo |
| Aplicación oficial en uso normal | ≤ 200 MB | ≤ 3 % | ≤ 1 % | — | — |
| Interfaz | — | — | — | — | 60 FPS estables como mínimo |

Una operación pesada puede superar el límite de forma temporal, pero debe volver
al objetivo al terminar. DylanOS Browser queda fuera de este presupuesto.

Equivalencias con el ecosistema actual:

- **DylanOS Settings** = DylanOS Configuration (`dylanos-configuration`), el único
  centro de configuración.
- **Files** = DylanOS Explorer (`dylanos-explorer`), el único explorador.
- **DylanOS Updater** = `dylanos-store --mode Update` y el notificador
  `dylanos-store-notifier`, que avisa de actualizaciones.

## Cómo medir

El arnés lee `/proc` directamente: no usa `psutil` ni estima valores.

```bash
# Aplicación: mide el árbol completo del proceso y lo termina al acabar.
python3 scripts/benchmarks/resource_benchmark.py \
  --name configuration --duration 15 --warmup 5 \
  --output benchmark-results/configuration.json \
  -- dylanos-configuration --page system

# Proceso ya abierto: no lo termina.
python3 scripts/benchmarks/resource_benchmark.py \
  --name explorer --duration 15 --warmup 5 --pid "$(pgrep -n dylanos-explorer)"

# Sistema en reposo: úsalo en la sesión real, sin apps de usuario abiertas.
python3 scripts/benchmarks/resource_benchmark.py \
  --mode system --duration 60 --warmup 10 \
  --output benchmark-results/idle.json
```

Cada ejecución escribe JSON y Markdown. El JSON conserva todas las muestras; el
Markdown resume promedio y máximo. El código de salida es `1` solo cuando una
métrica medida supera el límite; `incompleto` (por ejemplo, sin sonda de GPU o de
UI) no se presenta como aprobado.

Métricas que el arnés mide hoy:

- RAM RSS y PSS, swap y memoria usada del sistema.
- CPU por proceso (un núcleo) y normalizada al equipo completo.
- GPU del sistema desde `gpu_busy_percent` (amdgpu) o `nvidia-smi`.
- GPU por proceso desde los contadores `drm-engine-*` de `/proc/<pid>/fdinfo`.
- Bytes leídos y escritos por segundo, y número de procesos del árbol.

Si no existe una fuente real, la métrica queda como **no disponible** con su
motivo. No se rellena con cero.

Pendiente de sonda específica: tiempo de respuesta de UI y FPS/frame pacing.
Requieren una sesión gráfica real y un instrumento dentro de la ventana; el
arnés los marca como no disponibles en lugar de inventarlos.

## Línea base medida (2026-11-26)

Entorno: Intel Core i5-3210M (4 hilos), Linux 6.12.117, Qt 6.8.3 en el host y
6.8.2 en el chroot, `QT_QPA_PLATFORM=offscreen` y `QT_QUICK_BACKEND=software`.
Duración 12–18 s con 5–8 s de calentamiento descartados. Procesos nuevos.

| Aplicación | RAM RSS máx | RAM PSS máx | CPU media (equipo) | CPU máx (equipo) | Estado |
|---|---:|---:|---:|---:|---|
| DylanOS Configuration | 75,9 MiB | 74,2 MiB | 0,00 % | 0,00 % | dentro |
| DylanOS Explorer | 85,5 MiB | 71,7 MiB | 0,00 % | 0,00 % | dentro |
| Calculator | 54,5 MiB | 52,6 MiB | 0,00 % | 0,00 % | dentro |
| DylanOS App Center | 66,1 MiB | 64,3 MiB | 0,03 % | 0,36 % | dentro |
| Spotlight | 78,5 MiB | 66,0 MiB | 0,00 % | 0,00 % | dentro |
| Workspace (inicio) | 83,7 MiB | 70,5 MiB | 0,00 % | 0,00 % | dentro |
| Workspace (monitor) | 92,9 MiB | 79,6 MiB | 0,85 % | 2,84 % | dentro |
| DylanOS Store (binario instalado) | 227,4 MiB | 212,9 MiB | 1,15 % | 1,73 % | **fuera** |
| DylanOS Store (árbol actual) | 201,8 MiB | 185,7 MiB | 0,61 % | 10,44 %* | en el límite |

\* El máximo de CPU del Store es una muestra única durante una rotación del
destacado; la media es 0,61 %. La peor RSS observada en tres ejecuciones
independientes fue 203,4 MiB (mediana 198,6 MiB); detalle en la sección del
Store.

Notas de lectura:

- El arranque de las apps Python alcanza un pico de CPU de un núcleo (hasta 42 %
  en Workspace) mientras carga QML; con calentamiento, la CPU vuelve a ~0 %.
  Ese pico es una operación pesada temporal, no el estado de uso.
- Las cifras `offscreen` no miden GPU ni FPS. Sirven para comparar RAM/CPU entre
  versiones del mismo componente en el mismo entorno, no como certificado de la
  ISO.

## DylanOS Store: medición y desglose

El Store es la única app que se acerca al límite de 200 MiB, así que se mide
aparte, con más repeticiones. Entorno: el mismo chroot del ISO (`work/chroot`),
binario reconstruido del árbol actual y lanzado con `bwrap`; `HOME` y
`XDG_RUNTIME_DIR` temporales, `QT_QPA_PLATFORM=offscreen`,
`QT_QUICK_BACKEND=software`, `/var/lib/flatpak` sobre `tmpfs` y
`http_proxy`/`https_proxy` apuntando a un puerto cerrado.

Ese aislamiento no es cosmético: con el remoto `flathub` presente pero sin
metadatos, libostree aborta la tienda de forma intermitente
(`OSTree:ERROR:...glnx_close_fd: assertion failed: (errno != EBADF)`) al
refrescar AppStream. Es un hallazgo real, no un artefacto del arnés, y sigue sin
corregirse.

| Medición | RSS media | RSS máx | PSS máx | CPU media (equipo) | CPU máx (equipo) |
|---|---:|---:|---:|---:|---:|
| 3 ejecuciones de 12 s (`--view home`) | — | 198,6 MiB (mediana) | — | — | — |
| Arnés, 15 s tras 5 s de calentamiento | 201,8 MiB | 201,8 MiB | 185,7 MiB | 0,61 % | 10,44 % |

Las tres ejecuciones dan 200.120, 208.256 y 203.336 KiB de RSS máximo: la
dispersión entre arranques es de ±5 MiB, así que una sola medida no decide nada.
La mediana (198,6 MiB) queda 1,4 MiB por debajo del límite y la peor ejecución
(203,4 MiB) lo supera; la tienda está **en el límite**, no holgada. El arnés
marca `fail` porque su máximo (201,8 MiB) supera los 204.800 KiB, y es correcto
que lo haga.

Otros datos del mismo binario:

- Swap 0 KiB, un solo proceso y ningún hijo durante toda la ventana.
- Disco 0 B/s en la meseta: el catálogo ya está en memoria y no hay sondeos.
- La meseta de RSS se alcanza a los ~4 s (203.312 KiB estables de 4,0 a 9,5 s).
- CPU en reposo real: 0 ticks entre los segundos 4 y 15 con la vista de ajustes
  (sin rotación del destacado). En la portada, cada rotación del destacado
  (cada 7 s) consume ~0,26 s de CPU y el arranque completo ~3,5 s de CPU. Ese
  pico es una operación temporal; la media se queda en 0,61 % del equipo.
- GPU, latencia de UI y FPS: no disponibles (sin sesión gráfica real). No se
  sustituyen por cero.

### Efecto de la descripción diferida (A/B intercalado)

La lista del catálogo ya no retiene la descripción larga de las ~2.600 apps: se
pide al backend la primera vez que se abre una ficha (`longDesc()`), y la
búsqueda sigue encontrando coincidencias porque `AppFilterModel` consulta
`longDesc()` al puntuar. Ocho pares intercalados `eager`/`lazy` del mismo árbol:

| Variante | RSS máximo, mediana de 8 | RSS máximo, peor caso |
|---|---:|---:|
| Descripción en memoria (`eager`) | 200,8 MiB | 210,8 MiB |
| Descripción diferida (`lazy`) | 199,0 MiB | 202,2 MiB |

La mejora es de ~1,8 MiB de mediana: real, pero pequeña frente al total. El
grueso del consumo está en el catálogo completo de apps, los iconos y el heap de
Qt, no en las descripciones. El desglose por `smaps` del binario instalado (el
de 227,4 MiB) repartía el consumo en ~69 MiB de heap, ~46 MiB anónimos, ~18 MiB
de iconos Breeze y ~9 MiB del catálogo AppStream de la locale.

Se probó también quitar `layer.enabled` del `Loader` de la página del Store:
ahorra ~4 MiB, pero cambia el 1,8 % de los píxeles (degradados y antialiasing).
No se adoptó: la fidelidad visual manda.

### Hallazgos del Store (no corregidos en esta revisión)

1. **Catálogo completo al arrancar.** Las ~2.600 apps se cargan al inicio para
   que Buscar y Explorar tengan el modelo completo. Es la mayor palanca que
   queda para bajar de 200 MiB; exige carga por páginas o bajo demanda y una
   revisión de la búsqueda.
2. **Valoraciones ODRS descargadas y no mostradas.** `OdrsReviewsBackend`
   pide `/ratings` al construir el backend de PackageKit, pero la UI del Store
   no muestra valoraciones. Es una petición de red y una caché que no se usan.
3. **Contraste del destacado en modo claro.** El texto del héroe usa
   `Colors.fg` sobre una tarjeta oscura; en modo claro queda por debajo de un
   contraste cómodo. Pendiente de decisión de diseño.
4. **libostree aborta con un remoto sin metadatos** (descrito arriba). El
   aislamiento de la medición lo evita; la app sigue expuesta en un sistema con
   `flathub` a medio refrescar.

## Acciones aplicadas en esta revisión

- `dylanos-explorer`: la lista de dispositivos ya no se sondea cada 10 s.
  `KFilePlacesModel` avisa de altas, bajas y cambios; el temporizador queda solo
  para el espacio libre, que no tiene señal, y pasa a 60 s.
- `dylanos-configuration`: abrir un módulo KCM ya no bloquea el hilo de UI hasta
  4 s. La comprobación de candidatos es asíncrona y conserva el mismo contrato
  (`actionFailed` si ninguno sirve).
- `dylanos-configuration`: se corrigió una declaración fuera de ámbito de
  `LoginManagerService` en `main.cpp` que impedía compilar la app.
- `dylanos-store`: se corrigió `Colors.qml`, que declaraba `SystemPalette` como
  hijo de un `QtObject` raíz. El árbol compilaba, pero la tienda no arrancaba
  (error al cargar el singleton). Ahora es una propiedad `readonly`.
- `dylanos-store`: la descripción larga del catálogo se pide al abrir la ficha
  (`AppItem::longDesc()` + `PackageBackend::resourceLongDescription()`), en vez
  de retenerla para las ~2.600 apps. La búsqueda la consulta al puntuar, así que
  sigue encontrando coincidencias. Medido: −1,8 MiB de mediana.
- `dylanos-store`: la ficha y la página de actualizaciones dependen de
  `Store.shelfVersion`, así que abrirlas por enlace directo antes de cargar el
  catálogo ya no deja la vista vacía.
- `dylanos-store`: la descripción larga se muestra como texto enriquecido
  (`Text.RichText`); antes se veían las etiquetas `<p>` de AppStream.
- Arnés de medición completo: CLI, GPU de sistema y por proceso, modo `--pid`,
  JSON/Markdown y 22 pruebas unitarias.

## Lo que falta para cerrar la especificación

1. Medir el sistema en reposo en la ISO instalada (`--mode system`) y registrar
   RAM, CPU, swap y disco con la sesión ya asentada.
2. Añadir una sonda de latencia del bucle de eventos y de frame pacing dentro de
   una sesión real; sin ella, UI y FPS siguen sin certificar.
3. Bajar el Store por debajo de 200 MiB de forma sostenida: la mediana ya está
   en 198,6 MiB, pero la peor ejecución llega a 203,4 MiB. La palanca pendiente
   es el catálogo completo al arrancar, no las descripciones.
4. Repetir la tabla en hardware modesto y en la ISO, no solo en el host, y con
   una sesión gráfica real para medir GPU, latencia y FPS.
