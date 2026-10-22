# DylanOS — Mapa del Repositorio (memoria persistente)

DylanOS Crimson: distribución ligera basada en Debian 13 (trixie) + KDE Plasma 6 + Qt 6.8,
con identidad visual propia (crimson #DC143C sobre negro). Rama principal: **development**.
Remoto: SSH (`git@github.com:dylanneymarmontalvo2014-lgtm/DylanOS.git`). Documentación
técnica viva: `docs/architecture.md`. Este archivo es el índice operativo de reglas.

## Reglas de oro (no revertir accidentalmente)

- **DylanOS Explorer es el ÚNICO explorador de archivos** (`org.dylanos.explorer`): motor
  KIO real; el paquete `dolphin` no se envía (build.sh lo purga). Spotlight y workspace
  abren carpetas con `dylanos-explorer`, nunca con dolphin. El acceso "Archivos" del menú
  SIEMPRE ejecuta el binario real: stage.py borra `org.dylanos.files.desktop` (artefacto
  viejo que abría el workspace) y copia el `.desktop` canónico de la app; `dylanos --page
  explorer` NO existe (el workspace solo acepta welcome/files/notes/dev/monitor/settings).
  El `mimeapps.list` del skel asocia `inode/directory` al Explorer.
- **DylanOS Configuration es el ÚNICO centro de configuración** (`dylanos-configuration`,
  16 páginas + `SystemService` con kcmshell6/nmcli/pactl/bluetoothctl/plasma-apply-*).
  Los demás centros (systemsettings, kinfocenter, otros DE) se ocultan con NoDisplay desde
  `scripts/stage.py`. El paquete `systemsettings` SE CONSERVA: aporta `kcmshell6`.
- **Una sola app por función**: sin kcalc (la oficial es `dylanos-calculator`), sin
  VSCodium (el editor es Visual Studio Code, paquete `code`, repo apt oficial de Microsoft).
- **NUNCA mostrar "Discover/plasma-discover" al usuario**: la tienda es `dylanos-store`.
- **KWallet se mantiene** (plasma-nm guarda credenciales Wi-Fi con él).
- stage.py SIEMPRE hace staging a un root explícito y es idempotente (borra artefactos
  obsoletos: discover, dolphin, kcalc, org.dylanos.settings.desktop,
  org.dylanos.files.desktop…).
- `previews/` y docs históricos (`docs/*-2026-*.md`, `docs/superpowers/`, `.superpowers/`)
  son registros: no reescribirlos. `.claude/worktrees/` es un worktree viejo: no editar.
- Comentarios y UI en español. Sin simulaciones: cada control ejecuta la acción real.

## Colores oficiales (branding/colors/dylanos.conf)

- DYLANOS_RED=#DC143C · BLACK=#0A0A0A · WHITE=#FFFFFF · GRAY=#1A1A1A · LIGHT_GRAY=#B3B3B3
- Gradientes UI: primary `#e81740→#ad0a2a`, hover `#ff2a54→#c90e33`, down `#9c0b28→#7a051d`.
- "Liquid glass": bordes `#ff5274`/`#2e2736`, línea especular superior blanca translúcida.

## Reglas de ventanas y QML (lecciones de la 1.0 beta)

- Qt parsea colores de 8 dígitos como **#AARRGGBB** (NO #RRGGBBAA de CSS). Confundir el
  orden dejó la Configuration en negro (fondo casi transparente sobre ventana frameless).
- En Items hijos, `state` sin calificar resuelve a la propiedad integrada `Item.state`:
  usar SIEMPRE `root.state` para objetos de datos.
- Cada QML que use el singleton `Theme` debe importar `org.dylanos.configuration`.
- No redefinir propiedades FINAL de QQuickPopup (p. ej. `dim`); no usar `Overlay.*` con
  `import QtQuick.Controls.Basic`; declarar `required property int index` en delegates
  Repeater que usan `index`; hijos de Row/Column no pueden usar anchors horizontales/verticales.
- Ventanas DylanOS: `Qt.FramelessWindowHint` + controles integrados (semáforos izquierda,
  `startSystemMove()`). `setDesktopFileName` = nombre del `.desktop` sin extensión
  (app_id Wayland); `StartupWMClass` para X11. Apps de terceros: decoración Aurorae
  DylanOS (negra, sin banda gris; regenerar con `python3 scripts/lib/generate-theme.py aurorae`).
- Barra superior tipo menú: `com.dylanos.activeapp` (nombre completo de la app activa,
  sin cortes) + appmenu; se oculta sola en **pantalla completa real** vía
  `hiding=letwindowscover` (KWin; maximizada NO la cubre). Dock inferior: icontasks flotante.

## Estructura

- `apps/workspace/` — App QML/Python (PySide6) con 6 páginas; ventana DylanOS frameless
  (título y semáforos integrados en su barra). En el ISO: `/usr/share/dylanos/workspace`,
  wrapper `/usr/bin/dylanos --page <key>`. Su action("settings"|…) lanza `dylanos-configuration`.
- `apps/dylanos-app-center/`, `apps/dylanos-calculator/` — apps nativas; calculadora
  oficial (kcalc NO se envía). Calculator también es frameless con semáforos.
- `apps/dylanos-store/` — **DylanOS Store nativa**: fork de plasma-discover 6.3.6, UI 100%
  propia, datos reales vía libdiscover (PackageKit+AppStream+Flatpak). Binario `dylanos-store`,
  DBus `org.dylanos.dylanos-store`, desktop `org.dylanos.store.desktop`. QA de captura:
  `dylanos-store --screenshot out.png --size 1280x800 --view home` (chroot, con DBus).
- `apps/dylanos-spotlight/` — Búsqueda rápida (Python, ventana frameless).
- `apps/com.dylanos.dock/`, `apps/com.dylanos.activeapp/`, `apps/com.dylanos.search/`,
  `apps/dylanos-control-center/` — Plasmoids (dock alternativo, nombre de app activa,
  lupa que lanza Spotlight, centro de control con bandeja).
- `apps/dylanos-explorer/` — **DylanOS Explorer**: KIO real (KDirLister, KFilePlacesModel,
  FileUndoManager, OpenUrlJob) + operaciones reales en FileOperations (crear archivo y
  carpeta, renombrar, copiar/mover con progreso, papelera/restore/vaciar). Tests reales
  ctest (`tests/tst_fileoperations.cpp`). Icono de app_id: `org.dylanos.explorer`.
- `apps/dylanos-configuration/` — **DylanOS Configuration**: 16 páginas + SystemService.
  QA: `dylanos-configuration --page <p> --screenshot out.png --size 1280x800` (offscreen;
  stderr debe quedar limpio).
- `apps/archivos/` — prototipo histórico, NO se envía.
- `branding/` — logo.png (`distributor-logo-dylanos`), colors/, wallpapers/, icons/.
- `themes/` — look-and-feel `org.dylanos.crimson` (layout de 2 paneles), aurorae (negra),
  SDDM `DylanOS-Crimson`, GRUB, Plymouth, GTK DylanOS-Crimson(+Light, GTK3+GTK4), color-schemes.
- `configs/` — skel de Plasma (kwinrc aurorae, kdeglobals, gtk settings.ini con el tema
  GTK, konsole translúcido + fastfetch, mimeapps con Explorer por defecto), bashrc propio.
- `scripts/` — `build.sh` (chroot aislado; purga -dev, dolphin, kcalc al final),
  `iso.sh`, `stage.py`, `check.sh`, `test_QEMU.sh`, `lib/generate-theme.py` (aurorae etc.),
  `lib/packages.sh`. `scripts/tests/` — unittest Python + test_packages.sh.
- `installer/dylanos-installer/` — Instalador nativo Qt WebEngine.
- `artifacts/sddm-qa/` — capturas y métricas de la validación del SDDM (Test Greeter).
- `packages/{build,default,development,gaming,iot}` — listas de paquetes del ISO.

## SDDM (tema DylanOS-Crimson)

- Referencia visual oficial: `previews/pantalla de bloqueo/sddm_preview.png` (idéntica a
  `previews/DylanOS shell/sddm_preview.png`). Autenticación 100% real vía `sddm.login()`,
  usuarios reales del sistema (userModel) y foto de perfil de AccountsService donde estaba
  el icono de huella; el texto de la huella ES el campo de contraseña real. Apagar/Reiniciar/
  Suspender con `sddm.powerOff()/reboot()/suspend()`. El clima/música de las tarjetas es
  contenido de referencia (un greeter no accede a esos datos); reloj/calendario reales.
- Capturas de QA **opt-in**: `theme.conf → screenshot=<ruta>` ejecuta un grab del render
  tras 1,2 s (vacío en producción). Validación: `QT_QPA_PLATFORM=offscreen sddm-greeter
  --test-mode --theme <copia con background local>`; los errores deben mostrar
  ReferenceError/TypeError/fallback ausentes. Métricas en `artifacts/sddm-qa/`.

## QA (ejecutar antes de entregar)

```bash
DYLANOS_PYTHON=/tmp/opencode/venv/bin/python bash scripts/check.sh
```

- Valida: bash -n de todos los .sh, shellcheck, test_packages.sh, unittest completo módulo a
  módulo (proceso propio por suite; incluye test_store.py), compileall, staging (con
  desktop-file-validate) y carga QML offscreen de las 6 páginas del workspace + variante light.
- PySide6/psutil NO están en el python3 del sistema: usar venv (`/tmp/opencode/venv`) o
  instalar `python3-pyside6` + `python3-psutil` (los que usa el ISO: PySide6 6.8.2.1).
- Tests clave: `test_staging.py` (8 desktop entries org.dylanos.*, sin dolphin/kcalc/settings),
  `test_configuration.py` (app + staging), `test_sddm_theme.py` (Test Greeter real),
  `test_desktop.py` (layout de paneles con node), `test_store.py`, `test_ui.py`,
  `test_workspace.py`, `test_backend.py`, `test_packages.sh`.
- QA nativas específicas: capturas offscreen de las 16 páginas de Configuration (stderr
  limpio), `ctest` del Explorer en el chroot (incluye createFile), Test Greeter del SDDM con
  captura opt-in (artefactos en `artifacts/sddm-qa/`), `bash scripts/test_QEMU.sh` para el ISO.
- El host de desarrollo puede tener Qt más viejo que el chroot (6.4 vs 6.8): los builds y QA
  finales de binarios SIEMPRE en el chroot (`work/chroot`); para rebuilds manuales, reinstalar
  antes los build-deps (`packages/build/packages.list`) porque build.sh los purga al final.

## Empaquetado

- Visual Studio Code: paquete `code` del repo oficial `packages.microsoft.com/repos/vscode`
  (`packages/development/setup-repos.sh`, idempotente, borra restos de VSCodium). El
  `.desktop` real es `com.microsoft.VSCode.desktop` (Icon=vscode) — es el que fija el dock.
  Licencia del binario: la de Microsoft; documentada en `docs/licenses/assets.md`.
- build.sh purga al final: `-dev` exclusivos, `dolphin`, `dolphin-plugins`, `kcalc`,
  `codium` (chroots reutilizados). KF5/KWallet quedan según dependencias reales.
- ISO: `bash scripts/iso.sh` tras build.sh; manifest en `work/packages.manifest`.
  `iso.sh` re-ejecuta `scripts/stage.py` sobre el chroot ANTES del squashfs: los rebuilds
  manuales dejan el staging desactualizado y el ISO heredaría entradas `.desktop` y pines
  del dock viejos (así se coló un pin roto de VS Code en el ISO del 2026-10-21).

## Convenciones

- Comentarios y UI en español; código sin comentarios salvo los existentes.
- stage.py: staging SIEMPRE a un root explícito, idempotente (borra artefactos obsoletos).
- `previews/` y docs históricos (`docs/superpowers/`, `docs/*-2026-*.md`, `.superpowers/`) son
  registros: no reescribirlos. `unittest discover` (la flag de CLI) en docs históricos NO
  es una referencia a KDE Discover; no tocar.
- `.claude/worktrees/` es un worktree viejo (copia histórica): no editar.
- Git: mensajes estilo `feat(scope): …`/`fix(scope): …` en español, push por SSH a
  `origin development`. Nunca `git reset --hard` ni `git clean -fd` para "limpiar".
