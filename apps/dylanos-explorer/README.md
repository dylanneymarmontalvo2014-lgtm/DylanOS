# DylanOS Explorer

Gestor de archivos de **DylanOS Crimson** (Debian Stable + KDE Plasma) escrito con **Qt 6 / Qt Quick (QML) + C++17 + CMake**.
La interfaz reproduce la referencia visual de "Inicio" (barra lateral, tarjetas de carpetas, tabla de archivos recientes) y completa
las pantallas que la referencia no muestra con el mismo lenguaje visual.

> **Estado de verificación:** compilado y verificado en el chroot de DylanOS (Debian trixie, Qt 6.8.2):
> `cmake`+`ninja` en verde, `ctest` 1/1 (`tst_fileoperations`), la ventana abre con `--screenshot`
> (Inicio y una carpeta real con nombres Unicode/espacios/ocultos), y el binario se instala en el ISO.
> Verificación pendiente en sesión gráfica real (interacción con ratón/teclado) y comparación píxel a píxel.

## Dependencias (Debian 12/13)

```sh
sudo apt install build-essential cmake ninja-build \
  qt6-base-dev qt6-declarative-dev qt6-base-dev-tools \
  qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-templates \
  qml6-module-qtquick-layouts qml6-module-qtquick-window qml6-module-qtqml-workerscript \
  qml6-module-qtquick-shapes fonts-inter
```

Qt >= 6.4. Ningún comando de `sudo` se usa en la aplicación; solo para instalar dependencias.

## Compilar y ejecutar

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/dylanos-explorer            # abre en Inicio
./build/dylanos-explorer ~/Descargas # abre en una carpeta
ctest --test-dir build --output-on-failure
sudo cmake --install build           # opcional: binario, .desktop e icono
```

## Qué funciona (implementado en C++/QML, sin verificar)

- Navegación atrás / adelante / arriba, historial, Inicio, favoritos, dispositivos (`QStorageInfo`), papelera.
- Vistas de cuadrícula, lista (ordenable por columna), columnas y vista previa.
- Búsqueda (en Inicio busca en la carpeta personal; recursiva, limitada a 5000 resultados).
- Abrir (`QDesktopServices`), mostrar en carpeta, crear carpeta, copiar, cortar, pegar, renombrar, mover.
  El portapapeles es compatible con Dolphin/Nautilus.
- Copias grandes en segundo plano con progreso y cancelación.
- Papelera estándar freedesktop: enviar, restaurar, vaciar. Eliminación definitiva con confirmación.
- Selección múltiple (clic, Ctrl, Shift, Ctrl+A), propiedades (tamaño de carpetas calculado en segundo plano),
  archivos ocultos (Ctrl+H), nombres Unicode y rutas con espacios.
- Errores: carpeta inexistente, sin permisos, no es carpeta, resultados vacíos, carpeta vacía, notificaciones y diálogos.
- Atajos: Alt+←/→/↑, Backspace, F5, Ctrl+F, Ctrl+C/X/V, Ctrl+A, F2, Supr, Mayús+Supr, Ctrl+Mayús+N, Alt+Intro, Ctrl+H, Ctrl+, y Esc.

## Seguridad

- Sin `sudo`, sin `QProcess`, sin construir comandos con rutas. Todo usa `QFile`, `QDir` y `QDesktopServices`.
- `FileOperations::isProtectedPath` impide eliminar o renombrar `/`, `$HOME`, directorios de sistema de primer nivel y las carpetas XDG del usuario.
- Los permisos del usuario se respetan; los fallos se muestran, nunca se escalan.
- Las pruebas de `tests/` trabajan solo dentro de un `QTemporaryDir` y redirigen `XDG_DATA_HOME` allí.

## Pendiente / limitaciones conocidas

- **Barra de menús y dock** de la captura son parte del escritorio, no de la aplicación; no se incluyen.
- Navegación con flechas del teclado, selección por rectángulo y arrastrar y soltar: pendientes.
- Sin deshacer.
- Red: *Red local* abre `remote:/` (KIO) y *Servidor DLN* usa la URL configurada en Configuración (vacía por defecto).
  No hay navegación SMB/NFS propia.
- La vista de columnas es una aproximación (flujo compacto), no columnas jerárquicas.
- Textos solo en español, sin pipeline de traducción (`tr`/`.ts`). Unidades SI (kB = 1000 B).
- El listado de una carpeta es síncrono: no hay indicador de carga para directorios enormes (solo para operaciones de copia/mover).
- La papelera cubre únicamente `~/.local/share/Trash`, no las papeleras de otras particiones.
- Tema oscuro único (Crimson); no sigue el esquema de color de Plasma.
- La iconografía es propia (trazos SVG); no usa el tema de iconos del sistema.

Ver `docs/ARCHITECTURE.md`.
