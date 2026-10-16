# DylanOS — Mapa del Repositorio (memoria persistente)

Sistema operativo ligero basado en Debian + KDE Plasma, con identidad visual propia
(crimson #DC143C). Rama principal: **development**.

## Colores oficiales (branding/colors/dylanos.conf)

- DYLANOS_RED=#DC143C · BLACK=#0A0A0A · WHITE=#FFFFFF · GRAY=#1A1A1A · LIGHT_GRAY=#B3B3B3
- Gradientes UI habituales: primary `#e81740→#ad0a2a`, hover `#ff2a54→#c90e33`, down `#9c0b28→#7a051d`.
- Estética "liquid glass": bordes `#ff5274`/`#2e2736`, línea especular superior blanca translúcida.

## Estructura

- `apps/workspace/` — App QML/Python (PySide6) con 6 páginas: welcome, files, notes, dev, monitor, settings.
  - `main.py` (entry, acepta `--page`, `--smoke`, `--screenshot`, `--appearance`), `backend.py` (puente Qt), `core.py`.
  - `qml/`: Main.qml + páginas. Componentes de diseño: `Field.qml`, `ActionButton.qml` (primary=crimson), `Surface.qml` (tarjeta glass con gradiente según dark/light).
  - En el ISO se instala en `/usr/share/dylanos/workspace`; wrapper `/usr/bin/dylanos --page <key>` (lo genera `scripts/stage.py`).
- `apps/dylanos-app-center/` — Launcher fullscreen C++/QML (grid de apps instaladas, fondo carmesí humo, búsqueda píldora, puntos de paginación). Ejecutable `dylanos-app-center`.
- `apps/dylanos-store/` — **DylanOS Store nativa**: fork de plasma-discover 6.3.6 con UI 100% del prototipo (puerto QML verificado) y datos reales vía libdiscover.
  - `src/libdiscover/` — motor real conservado (recursos, transacciones, backends PackageKit+Flatpak ON; Snap/Fwupd/KNS/RpmOstree OFF).
  - `src/store/` — la app: `main.cpp` (ResourcesModel global, CLI `--mode Update|--search|--application|--screenshot`), `models/` (StoreController=QML singleton `Store`, AppItem/AppModel/AppFilterModel, providers de iconos), `services/` (contrato `PackageBackend`, `LibDiscoverBackend` real, `MockPackageBackend` solo tests), `qml/` (Main + theme×6 + components×24 + pages×9 del prototipo; sin StatesPage ni insignia demo), `data/` (iconos Lucide, Onest.ttf, `store-config.json` curación, `demo-apps.json` solo tests, logo DylanOS).
  - `src/notifier/` — agente de bandeja rebrandeado: binario `dylanos-store-notifier`, autostart `org.dylanos.store.notifier.desktop`, "Abrir DylanOS Store…", lanza `dylanos-store --mode Update`.
  - Puente de datos: `StoreController::loadFromResources(ResourcesModel*)` — catálogo AppStream real vía `backend->search(Filters{})` (stream "all"), categorías mapeadas AppStream→ids del prototipo (store-config.json), estados reales (none/installed/update) + transacciones (busy/progreso/error/cancel), favoritos y "instalado el" persistidos en QSettings("DylanOS","dylanos-store"), listas featured/popular/newest/essential/recommended curadas + relleno determinista, updates recalculadas en cada stateChanged.
  - Nombres: binario `dylanos-store`, DBus `org.dylanos.dylanos-store` (KDBusService Unique), desktop `org.dylanos.store.desktop`, ventana icono `dylanos-store`, header con logo DylanOS (`qrc:/data/logo.png`) + texto "DylanOS Store". **NUNCA mostrar Discover/KDE al usuario.**
  - Ventana solo tras catálogo listo (`catalogReady`) con watchdog de 20 s; QA de captura: `dylanos-store --screenshot out.png --size 1280x800 --view home` (en el ISO/chroot, con DBus).
- `apps/dylanos-spotlight/` — Búsqueda rápida (Python). `dylanos-spotlight`.
- `apps/com.dylanos.dock/` y `apps/com.dylanos.activeapp/` — Plasmoids Plasma.
- `apps/dylanos-explorer/` — **DylanOS Explorer**: gestor de archivos nativo Qt6/QML (ventana sin marco propia, sidebar + vistas grid/lista/columnas + preview, papelera freedesktop, QStorageInfo, operaciones con QtConcurrent + cancelación). C++ (FileListModel/PlacesService/ExplorerController/FileOperations) + QML `DylanOS.Explorer` (theme Theme/Icons singletons). Reemplaza los lanzadores de dolphin: dock inferior + workspace action("files") + stage.py (org.dylanos.explorer.desktop); dolphin sigue instalado como reversión. QA: `dylanos-explorer --screenshot out.png --size 1384x805 [--path dir]` (chroot, offscreen).
- `apps/archivos/`, `apps/calculator/` — Apps propias adicionales.
- `branding/` — logo.png (instalado como `distributor-logo-dylanos`), colors/, wallpapers/, icons/.
- `themes/` — Plasma look-and-feel `org.dylanos.crimson`, aurorae, SDDM, GRUB, Plymouth, GTK DylanOS-Crimson(+Light), color-schemes.
- `configs/` — skel de Plasma, konsole (translúcido 0.82 + fastfetch), bashrc propio.
- `scripts/` — `build.sh`, `iso.sh`, `stage.py` (staging idempotente hacia root explícito), `check.sh` (QA total), `test_QEMU.sh`, `lib/`.
- `scripts/tests/` — unittest Python (test_*.py) + `test_packages.sh`. QA QML offscreen de las 7 páginas vía `main.py --page X --smoke` con `QT_QPA_PLATFORM=offscreen`.
- `installer/dylanos-installer/` — Instalador nativo Qt WebEngine (dist/ + backend/ + native/).
- `previews/` — Capturas de referencia de diseño (PNG, no incluir en lógica).
- `packages/{build,default,development,gaming,iot}` — Listas de paquetes del ISO.

## Store (DylanOS Store)

- La tienda es la **app nativa `dylanos-store`** (fork de Discover en `apps/dylanos-store/`), ya NO plasma-discover rebrandeado: el workspace ya no tiene página `store` (6 páginas) y `backend.action("store"|"updates")` + `backend.findSoftware(q)` lanzan `dylanos-store`.
- Motor real: libdiscover del fork (PackageKit+AppStream+Flatpak). NUNCA mostrar el nombre "Discover/plasma-discover" al usuario.
- Logo: `branding/icons/dylanos-store.svg` (master) + PNG rasterizado en `branding/icons/dylanos-store.png` (icono hicolor 512 en staging). Logo de marca en el header de la app: `branding/logo.png` embebido en `qrc:/data/logo.png`.
- Entrada desktop: la instala el CMake del fork (`org.dylanos.store.desktop`, Name=DylanOS Store, Icon=dylanos-store, Exec=dylanos-store); `scripts/stage.py` escribe una versión equivalente ANTES del build (fallback idempotente) y borra restos de `org.kde.discover` en chroots reutilizados.
- ISO: `scripts/build.sh` compila el fork en el chroot (`cmake -GNinja` + `ctest` + `cmake --install`) y purga los `-dev` exclusivos de la tienda al final. Runtime: `appstream`, `libpackagekitqt6-1`, `packagekit`, `flatpak` (en `packages/default`); build deps en `packages/build`.
- Compilación local rápida: chroot de pruebas `work/discover-build` (trixie + build-deps) con `/tmp/opencode/build_store.sh` (no forma parte del repo).

## QA (ejecutar antes de entregar)

```bash
DYLANOS_PYTHON=/tmp/opencode/venv/bin/python bash scripts/check.sh
```

- Valida: bash -n de todos los .sh, shellcheck, test_packages.sh, unittest completo módulo a módulo (proceso propio por suite; incluye test_store.py del fork), compileall, staging (con desktop-file-validate) y carga QML offscreen de las 6 páginas del workspace + variante light.
- PySide6/psutil NO están en el python3 del sistema: usar venv (`/tmp/opencode/venv`) o instalar `python3-pyside6` + `python3-psutil` (los que usa el ISO: PySide6 6.8.2.1).
- Tests clave: `test_staging.py` (cuenta 8 desktop entries org.dylanos.*), `test_store.py` (fork de la tienda sin rastro de Discover), `test_ui.py`, `test_workspace.py`, `test_backend.py`.
- `unittest discover` (la flag de CLI) aparece en docs históricos: NO es una referencia a KDE Discover; no tocar.

## Convenciones

- Comentarios y UI en español; código sin comentarios salvo los existentes.
- stage.py: staging SIEMPRE a un root explícito, idempotente (borra artefactos obsoletos).
- `previews/` y docs históricos (`docs/superpowers/`, `docs/*-2026-*.md`, `.superpowers/`) son registros: no reescribirlos.
- `.claude/worktrees/` es un worktree viejo (copia histórica): no editar.
