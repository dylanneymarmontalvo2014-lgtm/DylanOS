# DylanOS Workspace

Aplicación de escritorio Python/PySide6 con seis páginas accesibles mediante `dylanos --page <página>`:

| Clave | Página | Función |
|---|---|---|
| `welcome` | Bienvenida | Accesos rápidos, actualizaciones y entradas a otras áreas |
| `files` | Archivos | Navegación local básica, filtro, favoritos, ocultos y operaciones habituales |
| `notes` | Notas | Notas de texto locales guardadas en SQLite |
| `dev` | Desarrollo | Detector acotado de herramientas y creación local de proyectos Python, Web y C++ |
| `monitor` | Monitor | CPU, memoria, disco, procesos y uptime; actualización cada 2,5 s, pausables |
| `settings` | Ajustes | Apariencia y accesos a DylanOS Configuration/KCM |

Sin argumentos abre `welcome`. Ejemplos:

```sh
dylanos
dylanos --page notes
dylanos --page monitor
```

El backend vive en `backend.py` y separa operaciones del sistema del QML. Los datos de notas están en la ubicación de datos XDG del usuario, en `DylanOS/Workspace/notes.sqlite3`; las notas no se sincronizan remotamente. Las plantillas se escriben en la carpeta indicada por la persona y no descargan paquetes.

`files` es un explorador básico del Workspace, no reemplaza el gestor completo DylanOS Explorer. Para las capacidades KIO, dispositivos, protocolos remotos, papelera completa y otras limitaciones, consulta [`../dylanos-explorer/README.md`](../dylanos-explorer/README.md). La página de monitor no sustituye la administración avanzada de procesos de Plasma System Monitor.

Las opciones `--smoke`, `--screenshot <ruta>` y `--appearance dark|light` se destinan a QA; pueden necesitar una sesión/offscreen Qt con PySide6 y no son necesarias al abrir la app normalmente.

Consulta la [guía de uso general](../../docs/guia-de-uso.md) y la [arquitectura](../../docs/architecture.md).