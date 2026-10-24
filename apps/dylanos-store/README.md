# DylanOS Store

Tienda nativa Qt 6/QML con backend C++ `LibDiscoverBackend` y `CatalogSync`. La app puede consultar recursos mediante libdiscover y sus backends disponibles, y realizar operaciones de instalación/actualización/desinstalación a través de la transacción del backend, con autorización de PackageKit/polkit cuando corresponda. No ejecuta comandos de shell ni pide/almacena contraseñas. La disponibilidad del catálogo y las operaciones depende de PackageKit, AppStream, Flatpak, repositorios, conectividad y autorización de polkit en el sistema.

## Uso diario

Abre desde el menú o ejecuta:

```sh
dylanos-store
dylanos-store --mode Update
dylanos-store --mode Installed
dylanos-store --mode Browse
dylanos-store --search firefox
```

La interfaz reúne inicio, categorías, búsqueda, ficha de app, biblioteca/instaladas, actualizaciones y ajustes. `--mode Browse` abre navegación por categorías. El resultado no garantiza que una fuente concreta esté configurada o que una operación de paquete tenga éxito. La instalación real puede solicitar autorización de sistema.

## Opciones de desarrollo/QA

`--view`, `--size`, `--screenshot` y `--delay` preparan vista y captura. `--action` es una opción repetible de QA para ejecutar acciones antes de la captura (por ejemplo `install:ID`, `update:ID`, `updateAll`, `offline`, `query:TEXTO`, `open:OBJETO`); no es necesario para uso común. Las capturas no demuestran que los paquetes se instalaron.

## Implementación y alcance

- Ejecutable C++17/Qt/QML: `src/store/`; controlador/modelos: `src/store/models/`; puente a recursos: `LibDiscoverBackend`; interfaz: `src/store/qml/`.
- El backend de producción del binario está configurado como `LibDiscoverBackend`, no como el `MockPackageBackend` del prototipo antiguo. Ver [`src/store/services/LibDiscoverBackend.h`](src/store/services/LibDiscoverBackend.h).
- `apps/dylanos-store/docs/README-prototipo.md`, `PACKAGE_BACKEND.md`, `ARCHITECTURE.md` y `DESIGN_MAPPING.md` conservan notas y contratos de diseño; leer el código y el build actual antes de extrapolar afirmaciones históricas del prototipo.
- La versión empaquetada y las pruebas automáticas no acreditan que haya un repositorio conectado o que todas las acciones se completen en hardware.

Para uso y limitaciones del resto del sistema, consulta la [guía DylanOS](../../docs/guia-de-uso.md); para empaquetado, [`src/CMakeLists.txt`](src/CMakeLists.txt).
