# Arquitectura

```
dylanos-explorer/
├── CMakeLists.txt
├── assets/                   .desktop e icono SVG
├── qml/
│   ├── Main.qml              Ventana sin marco, atajos, menús, diálogos, toasts
│   ├── theme/                Theme.qml (tokens), Icons.qml (trazos SVG)   [singletons]
│   ├── components/           Piezas reutilizables: Sidebar, Header, vistas, diálogos...
│   └── pages/                HomePage (referencia) y DirectoryPage (resto de carpetas)
├── src/
│   ├── main.cpp
│   ├── models/               FileListModel (QAbstractListModel), PlacesService
│   └── services/             FileOperations, Formatters (Qt Core puro) y ExplorerController
└── tests/tst_fileoperations.cpp   QtTest sobre QTemporaryDir
```

## Motor (basado en Dolphin)

La capa de datos NO es propia: es la que Dolphin usa en producción (KIO/KF6), de modo que el
comportamiento con la papelera, dispositivos, red, permisos y deshacer es idéntico al de Dolphin:

- `FileListModel` lista con `KDirLister` (todos los protocolos, refresco automático, lotes).
- `PlacesService` lee dispositivos/lugares con `KFilePlacesModel` (Solid) y monta bajo demanda.
- `ExplorerController` ejecuta `KIO::trash/del/emptyTrash/restoreFromTrash`, abre con
  `KIO::OpenUrlJob` y deshace con `KIO::FileUndoManager`. Las copias/movimientos locales se
  mantienen en `FileOperations` (probados por unidad) y las remotas van por KIO.
- `FileOperations` conserva las rutas protegidas y el análisis `.trashinfo`.

## Capas

1. **`services/FileOperations` y `Formatters`**: Qt Core únicamente, sin dependencia de QML.
   Se compilan como biblioteca estática (`explorer_services`) y las usa también el ejecutable de pruebas.
   Contiene toda la lógica destructiva (copiar, mover, papelera, borrado) y las rutas protegidas.
2. **`models/`**: `FileListModel` lista un directorio (o busca recursivamente), ordena (carpetas primero, orden numérico
   con `QCollator`), mantiene la selección y recarga con `QFileSystemWatcher` (con antirrebote de 200 ms).
   `PlacesService` expone favoritos, dispositivos, carpetas de Inicio y archivos recientes.
3. **`ExplorerController`**: único objeto que ve la UI. Mantiene ubicación e historial, portapapeles, ajustes (`QSettings`)
   y ejecuta las operaciones largas en `QtConcurrent` con progreso y cancelación, notificando mediante `notify()`.
4. **QML**: sin lógica de archivos. Las acciones llaman al controlador; las confirmaciones destructivas viven en `Main.qml`.

## Convenciones QML

- Todo el módulo es `DylanOS.Explorer` (`qt_add_qml_module`). `Theme` e `Icons` son singletons.
- Los componentes reciben `ctl` y `places` por propiedades; no hay estado global oculto.
- Las vistas emiten `itemContext` / `backgroundContext` en coordenadas de ventana; `Main.qml` decide el menú.
- Se usa el estilo *Basic* de Qt Quick Controls solo como base (`ScrollBar`, `Popup`); todo el aspecto es propio.

## Ubicaciones especiales

`home://` es la pantalla de Inicio. Las demás ubicaciones son rutas reales. La papelera es
`~/.local/share/Trash/files` y se detecta con `FileOperations::isInTrash`.
