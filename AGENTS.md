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
  VSCodium (el editor es Visual Studio Code, paquete `code`, repo apt oficial de Microsoft)
  y sin Konsole (la terminal oficial es `dylanos-console`, basada en Kitty).
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
  stderr debe quedar limpio). `sysInfo()`: CPU con cadena de fuentes (/proc/cpuinfo
  "model name" o "Hardware" → `lscpu` "Model name:" → "Procesador de N núcleos") porque
  el kernel OMITE "model name" cuando la marca del CPUID está vacía (p. ej. QEMU TCG con
  `-cpu max`) y la página quedaba en "—"; RAM redondeada: MemTotal recorta la memoria que
  reserva el firmware, así que se ajusta a la potencia de dos más próxima si queda a
  ≤10 % (7,6 GiB → "8 GB", 15,4 → 16, 11,6 → 12; nunca "7.60 GB").
- `apps/archivos/` — prototipo histórico, NO se envía.
- `branding/` — logo.png (`distributor-logo-dylanos`), colors/, wallpapers/, icons/.
- `themes/` — look-and-feel `org.dylanos.crimson` (layout de 2 paneles), aurorae (negra),
  SDDM `DylanOS-Crimson`, GRUB, Plymouth, GTK DylanOS-Crimson(+Light, GTK3+GTK4), color-schemes.
- `configs/` — skel de Plasma (kwinrc aurorae, kdeglobals, GTK, mimeapps), configuración
  de Kitty/Neofetch y bashrc propio con prompt y recomendaciones fantasma.
- `Makefile` — incluye `make iso-validated` (build → ISO → test-iso en secuencia) y `BUILD_JOBS=N`.
- `scripts/` — `build.sh` (chroot aislado; transacción APT agrupada, hasta 4 jobs CMake
  configurables con `DYLANOS_BUILD_JOBS`, purga -dev, dolphin, kcalc y konsole al final),
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

## DylanOS Console

- **Única terminal**: Kitty, lanzada siempre mediante `/usr/bin/dylanos-console`; nombre
  visible `DylanOS Console`, desktop/app id `org.dylanos.console`, icono propio
  `branding/icons/dylanos-console.{svg,png}`. Los lanzadores genéricos de Kitty se ocultan
  y `build.sh` purga `konsole` de chroots reutilizados.
- Configuración: `configs/kitty/kitty.conf` (JetBrains Mono, paleta Crimson,
  opacidad 0,40, blur 24, pestañas minimalistas, 50.000 líneas); se instala tanto en
  `/etc/xdg/kitty` como en el skel.
- Neofetch sustituye a Fastfetch. Debian 13 ya no publica el paquete original: se instala
  `neowofetch` (fork compatible mantenido) y `/usr/bin/neofetch` es el wrapper estable de
  DylanOS. `configs/neofetch/config.conf` usa el backend gráfico `kitty` y la imagen real
  `branding/logo.png`, instalada como `/usr/share/dylanos/neofetch/logo.png`; no hay ASCII.
- `configs/bash/dylanos-ghost.sh` completa desde historial o comandos y lo acepta con
  Tab o flecha derecha. No repinta la línea al teclear: los bindings por carácter
  encadenaban macros de Readline ("maximum macro execution nesting level exceeded") y
  bloqueaban la entrada. Solo registra binds en Bash interactivo; debe poder sourcearse
  sin ruido en modo no interactivo.
- QA principal: `test_shell_contract.py` ejecuta una recomendación real y su aceptación;
  `test_staging.py` valida launcher, app id, iconos, Neofetch, limpieza heredada y defaults;
  `test_packages.sh` valida Kitty/Neowofetch/ImageMagick, el wrapper y la ausencia de
  Konsole/Fastfetch.

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
  `.desktop` que instala ese paquete es `com.microsoft.VSCode.desktop` (Icon=vscode) y es
  el ÚNICO id válido para fijar en el dock; NO existe `code.desktop` (el nombre del
  paquete NO es el nombre del .desktop) y fijarlo deja el icono del dock roto.
  Licencia del binario: la de Microsoft; documentada en `docs/licenses/assets.md`.
- build.sh purga al final: `-dev` exclusivos, `dolphin`, `dolphin-plugins`, `kcalc`,
  `konsole`, `codium` (chroots reutilizados). KF5/KWallet quedan según dependencias reales.
- Ejecutar `./scripts/build.sh` sin `sudo`: compila el frontend como el usuario actual y
  eleva privilegios internamente para el chroot. Si `work/chroot` existe, usar `--resume`.
  La entrada externa como root se rechaza para no dejar `node_modules`/`dist` con dueño root.
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
