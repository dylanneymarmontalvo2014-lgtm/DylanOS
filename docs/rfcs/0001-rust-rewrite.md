# RFC: Migrar las apps Python de DylanOS (archivos, spotlight, workspace) a Rust/C++ nativo

> Esta copia conserva la RFC adjunta al issue. La Fase 0 se ejecuta por separado; este documento no autoriza a implementar las fases siguientes en el mismo PR.

## Categoría

`rfc`, `enhancement`, `performance`, `architecture`, `rust`, `needs-discussion`

## Resumen

Tras revisar el código real de la rama `development`, el ecosistema de apps de DylanOS **no es homogéneo**:

| App | Stack actual | Rendimiento esperado |
|---|---|---|
| `dylanos-explorer`, `dylanos-configuration`, `dylanos-app-center`, `calculator`, `dylanos-process` | C++/Qt (CMake) + QML | Nativo, sin overhead de intérprete |
| `com.dylanos.dock/search/dashboard/activeapp`, `dylanos-control-center` | Plasmoids QML | Corren sobre el motor QML de Plasma, no son binarios aparte |
| `dylanos-browser` | Fork de Zen/Gecko, JS/TS + utilidad `ffprefs` en Rust | Fuera de alcance: es un motor de navegador |
| **`archivos`, `dylanos-spotlight`, `workspace`** | **Python + QML** | El overhead debe medirse antes de cualquier migración |

La propuesta original evalúa migrar las tres apps a Rust, utilizando `ffprefs` como precedente. Esta RFC no propone tocar las aplicaciones C++/Qt, plasmoides, el navegador ni el instalador web. La app `archivos` actualmente delega a la página files de Workspace y no usa su QML de prototipo.

## Motivación y riesgos

La latencia de Python, I/O y consultas repetidas se debe verificar mediante medición, no asumir. Incorporar Rust añade toolchain, dependencias, cambios de empaquetado Debian y superficie de CI. Los bindings QML Rust deben probarse por aplicación. Debe respetarse `AGENTS.md`, evitar duplicar funciones y mantener las reglas existentes de ventanas frameless, QML y colores Qt.

## Alcance

- `apps/dylanos-spotlight`: `backend.py`, `calculator.py`, `exec_utils.py`, `main.py`.
- `apps/workspace`: `backend.py`, `core.py`, `main.py`.
- `apps/archivos`: `main.py`.

Fuera de alcance: las apps C++/Qt, los plasmoides `com.dylanos.*`, DylanOS Browser y `installer/dylanos-installer`.

## Criterios de aceptación originales

- [ ] Línea base de rendimiento (tiempo de arranque, RSS) de `archivos`, `dylanos-spotlight` y `workspace`.
- [ ] Decisión de stack Rust/QML validada con un piloto de una sola app (`dylanos-spotlight`).
- [ ] Medición post-piloto comparada contra la línea base.
- [ ] Plan de empaquetado Debian del binario Rust integrado a `scripts/build.sh` sin romper `scripts/check.sh`.
- [ ] Las otras apps solo migran tras aprobar el piloto.

## Plan de implementación

### Fase 0 — Línea base (sin tocar código de producto)

- Medir arranque y RSS de las tres apps Python actuales.
- Documentar el método y los resultados en [`docs/benchmarks/apps-python-baseline.md`](../benchmarks/apps-python-baseline.md).

### Fase 1 — Piloto: una app

- Elegir `dylanos-spotlight`, la más pequeña y sensible a latencia.
- Migrar `backend.py`, `calculator.py` y `exec_utils.py` a Rust, conservando la UI QML.
- Mantener el mismo contrato de datos de QML y agregar pruebas equivalentes a las del límite seguro del evaluador de expresiones.

### Fase 2 — Validación

- Medir arranque/RSS y comparar contra Fase 0 en condiciones equivalentes.
- Decidir si el crate/binding es viable para otras apps.

### Fase 3 — Extensión, solo tras aprobar el piloto

- Evaluar Workspace en una fase/PR propio.
- Evaluar `archivos` separadamente, respetando que el menú «Archivos» del sistema abre DylanOS Explorer.

### Fase 4 — Empaquetado

- Evaluar `rustc`/`cargo`, crates de sistema, integración a `scripts/build.sh` y CI después de validar el piloto; decidir de forma explícita el empaquetado Debian.

## Proceso de trabajo

Cada fase se entrega mediante pull request contra `development`, nunca con commit directo. Cada PR debe pasar `scripts/check.sh` y el lint correspondiente, adjuntar métricas comparables cuando cambie una app, respetar `AGENTS.md` y documentar con precisión qué se probó y qué queda pendiente según `CONTRIBUTING.md`.
