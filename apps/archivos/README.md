# Archivos — DylanOS 1.0 Beta

`python3 main.py` abre la implementación real compartida en `../workspace`.
Requiere PySide6 6.8+ y psutil.

Incluye navegación del sistema de archivos, historial, búsqueda por nombre en la
carpeta actual, favoritos XDG, vistas de lista/iconos, archivos ocultos, apertura
con la aplicación predeterminada, creación de carpetas, copia, pegado,
renombrado sin sobrescritura y papelera con confirmación. Los errores aparecen en
la ventana; las operaciones largas se ejecutan en segundo plano.

Dolphin sigue siendo el gestor predeterminado y ofrece selección múltiple,
arrastrar y soltar, ubicaciones remotas, dispositivos y recuperación de papelera.
El botón «Abrir en Dolphin» abre la carpeta actual.

`qml/Main.qml` y `assets/` conservan el prototipo anterior sin alteraciones.
Ese prototipo contiene un árbol de ejemplo: no es la implementación que ejecuta
la beta. `main.py` no carga `qml/Main.qml`; el prototipo conserva datos
simulados únicamente como referencia visual y cualquier cambio funcional debe
hacerse en Workspace. Las etiquetas, columnas y favoritos personalizados del
prototipo aún no están conectados a disco y no se anuncian en la aplicación
nueva.
