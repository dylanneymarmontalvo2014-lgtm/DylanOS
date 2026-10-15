# DylanOS Store — integración con el sistema de paquetes

## 1. Estado real del proyecto

El repositorio es una **aplicación React + Vite + TypeScript**. No contiene QML, C++ ni CMake, así que no es todavía un cliente Qt 6. Todo el estado de instalación es **simulado**.

| Capa | Archivo | Estado |
|---|---|---|
| Contrato del backend | `src/services/types.ts` (`PackageBackend`, `AppState`, `BackendEvent`) | Nuevo |
| Backend simulado | `src/services/mockBackend.ts` (`MockPackageBackend`) | Nuevo; simula, no instala nada |
| Proveedor / compatibilidad | `src/store.tsx` (`StoreProvider`, `useStore`) | Mismo API para las pantallas; ahora delega en el backend |
| Catálogo de demostración | `src/data.ts` | Datos ficticios, centralizados |
| Pantallas y componentes | `src/App.tsx`, `src/views.tsx`, `src/ui.tsx` | Sin cambios |

Las pantallas siguen consumiendo `useStore()` con las mismas propiedades (`st`, `install`, `update`, `updateAll`, `uninstall`, `cancel`, `retry`, `version`...). `StoreProvider` acepta un `backend` inyectable.

Pruebas: `pnpm test` (7 pruebas del backend simulado: estados, progreso, cancelación, fallo y reintento, modo sin conexión, inmutabilidad de snapshots).

## 2. Qué se verificó de KDE Discover (rama master, Plasma 6.8)

- Estructura: `libdiscover/` (núcleo), `discover/` (app y QML), `libdiscover/backends/*`. Cada backend implementa `AbstractResourcesBackend` (`search`, `installApplication`, `removeApplication`, `checkForUpdates`, `backendUpdater`...). `ResourcesModel` agrega los backends y se expone a QML en el módulo `org.kde.discover` (`discover/DiscoverDeclarativePlugin.cpp`).
- Backends: PackageKit, Flatpak, Snap, Fwupd, KNS, RpmOstree, AlpineApk, AppStreamPreview y Dummy (Dummy está desactivado por defecto).
- PackageKit: `PKTransaction` **simula primero** (`TransactionFlagSimulate`), pide confirmación si se eliminarían otros paquetes y falla si afectase a uno crítico; después ejecuta con `OnlyTrusted`. Los metadatos vienen de `AppStream::Pool`. La autenticación la resuelve el demonio PackageKit.
- Concurrencia: no se encontró una cola global de transacciones en el código de Discover que se leyó. Solo hay guardas para refrescos y actualizaciones dentro del backend PackageKit. El orden real lo impone el demonio PackageKit, aunque esto **no se verificó**.
- Fuentes: `AbstractSourcesBackend`. En PackageKit solo se pueden listar y activar o desactivar repositorios; no se pueden añadir ni quitar.
- Pruebas: hay pruebas con el backend Dummy (`dummytest`, `updatedummytest`, `headless-updates`) y una prueba GUI de Flatpak con Appium. No se encontraron pruebas del backend PackageKit.
- **`libdiscover` es una biblioteca privada** (sin SOVERSION ni cabeceras instaladas). No se puede enlazar desde otra aplicación.
- Debian estable (trixie): `plasma-discover` 6.3.6, `packagekit` 1.3.1, `libpackagekitqt6` 1.1.2, `libappstreamqt` 1.0.5. El código de master exige Qt 6.11 y KF6 6.30; que trixie no los ofrece **no está verificado**.

Fuentes: <https://invent.kde.org/plasma/discover> (`CMakeLists.txt`, `libdiscover/resources/AbstractResourcesBackend.h`, `libdiscover/backends/PackageKitBackend/PKTransaction.cpp`, `.../PackageKitSourcesBackend.cpp`, `libdiscover/CMakeLists.txt`), <https://tracker.debian.org/pkg/plasma-discover>, <https://tracker.debian.org/pkg/packagekit-qt>.

## 3. Diseño propuesto (pendiente de implementar)

Se recomienda un **servicio nativo propio sobre PackageKit**:

1. Un demonio o proceso Qt 6/C++ usa `PackageKitQt6` y `AppStreamQt` para búsqueda, instalación, desinstalación, actualizaciones y repositorios.
2. Debe copiar los patrones de Discover: simulación previa, confirmación de paquetes extra, un modelo de transacciones y fallo ante paquetes críticos.
3. Las operaciones privilegiadas las autoriza el demonio PackageKit mediante polkit. La interfaz nunca ejecuta `apt` ni `sudo`.
4. Las operaciones se encolan para ejecutarse de una en una, sin mutar la base de datos de dpkg por otro camino.
5. Este código cumpliría el contrato `PackageBackend`. Si el frontend sigue siendo web, se necesita un puente (D-Bus, WebSocket local o similar); si se porta a QML, el contrato se convierte en `QAbstractListModel` y `QObject`.

Alternativas evaluadas:

| Opción | A favor | En contra |
|---|---|---|
| Servicio propio sobre PackageKit | API pública, Qt 6, polkit, funciona en Debian | Hay que escribirlo y mantenerlo |
| Vendorizar `libdiscover` | Reutiliza la lógica | API privada, exige Qt 6.11 / KF6 6.30, mantenimiento cuesta |
| Usar Discover tal cual con un backend propio | Mínimo código | No es una interfaz propia; contradice el diseño aprobado |
| Llamar a `apt` desde la app | Sencillo | Inseguro, sin simulación, riesgo de conflictos; **descartado** |

Dependencias previstas: `libpackagekitqt6-dev`, `libappstreamqt-dev`, Qt 6 y los demonios `packagekit` y `polkit`. Se instalarían con apt tras aprobación.

## 4. Qué funciona y qué no

Funciona (solo simulado): flujo de instalar, actualizar, cancelar, reintentar y desinstalar, errores recuperables, estado sin conexión y toasts.

No integrado todavía: búsqueda y catálogo reales (AppStream), instalación real, autenticación polkit (el diálogo es de demostración), repositorios, dependencias y conflictos, valoraciones, iconos y capturas reales, y el historial de uso.

La cola de operaciones, la simulación previa y el borrado de datos de demostración son tareas pendientes del backend real.
