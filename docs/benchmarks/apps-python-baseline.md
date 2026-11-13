# Línea base de arranque y memoria: apps Python

Esta línea base corresponde a la **Fase 0** del RFC [Migrar apps Python de DylanOS a Rust/C++ nativo](../rfcs/0001-rust-rewrite.md). Solo mide el código Python actual en `development`; no cambia las apps ni inicia el piloto Rust.

## Alcance

Se miden `archivos`, `dylanos-spotlight` y `workspace`, en procesos nuevos y con una instalación y entorno de ejecución comunes. `archivos` es hoy un lanzador que abre la página de archivos de Workspace; su antigua UI QML de prototipo no forma parte de la medición. Se ejecuta QML con el plugin `offscreen` y backend Quick `software`, sin display físico.

## Método reproducible

El script [`scripts/benchmarks/benchmark_python_apps.py`](../../scripts/benchmarks/benchmark_python_apps.py) arranca cada aplicación con su opción `--smoke`. Mide el tiempo desde el inicio del proceso hasta el primer turno del event loop de Qt después de cargar QML y comprobar que existe un objeto raíz. Durante la vida del proceso muestrea `VmRSS` y `VmHWM` en `/proc`; informa la máxima lectura. Usa diez muestras por app después de una ejecución de calentamiento, además de procesos nuevos y un directorio `HOME` temporal por app. Resume mediana y p95 de arranque, y mediana y máximo de RSS. Conserva las lecturas individuales como JSON en el artefacto `apps-python-baseline` de GitHub Actions.

Son **procesos nuevos, no arranques en frío del sistema**: no se vacía la caché de páginas del kernel. La carga se mide con Qt offscreen/software; la latencia gráfica en una sesión Plasma real no se infiere de estos datos. El benchmark falla si una app no carga QML, no termina en el plazo o no se puede leer RSS; no sustituye un fallo por un valor estimado.

Para repetir localmente desde la raíz del repositorio con las dependencias de QA instaladas:

```bash
python3 scripts/benchmarks/benchmark_python_apps.py --output-dir benchmark-results
```

El workflow `Benchmark Python apps` ejecuta las mismas diez muestras, publica este resumen en el step summary y adjunta el JSON y el Markdown por SHA.

## Resultado

Las mediciones se registrarán aquí después de ejecutar el workflow en GitHub Actions sobre el SHA de la rama de esta PR, junto con las versiones de Python/PySide6/Qt y el SHA medido. No se presentan tiempos simulados ni cifras obtenidas en un entorno distinto.

| App | Arranque mediana (ms) | Arranque p95 (ms) | RSS pico mediana (MiB) | RSS pico máximo (MiB) |
|---|---:|---:|---:|---:|
| `archivos` | Pendiente del workflow | Pendiente | Pendiente | Pendiente |
| `dylanos-spotlight` | Pendiente del workflow | Pendiente | Pendiente | Pendiente |
| `workspace` | Pendiente del workflow | Pendiente | Pendiente | Pendiente |

## Siguiente fase

Este PR solo establece la medición de Fase 0. La selección de binding/crate Qt-Rust, el piloto de Spotlight, cambios al empaquetado Debian y cualquier migración de `workspace` o `archivos` requieren su fase y revisión separadas. No se atribuye una mejora de rendimiento hasta comparar mediciones del mismo runner/configuración con una versión posterior funcional.
