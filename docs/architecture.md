# Arquitectura de DylanOS

DylanOS Crimson 1.0 es una distribución basada en Debian 13 (trixie) con KDE Plasma 6,
Qt 6/QML y una capa de aplicaciones y recursos visuales propios. Este documento describe
la arquitectura **real** del repositorio tras la iteración de ingeniería de 2026-10.

## 1. Capas del sistema

1. **Base**: Debian trixie + systemd + KDE Plasma 6 (kwin, kio, kconfig, KCM), Qt 6.8.
2. **Aplicaciones nativas DylanOS** (C++/QML o Python/QML, todas con UI propia):
   `dylanos` (workspace, PySide6, 6 páginas), `dylanos-explorer` (gestor de archivos
   único del sistema), `dylanos-store` (tienda, fork de Discover con libdiscover real),
   `dylanos-configuration` (centro de configuración único), `dylanos-app-center`,
   `dylanos-calculator`, `dylanos-spotlight`, `dylanos-installer`.
3. **Shell del escritorio**: paneles Plasma generados por el layout del look-and-feel
   (`org.dylanos.crimson`) con plasmoids propios (`com.dylanos.activeapp`,
   `com.dylanos.search`, `com.dylanos.controlcenter`) y `org.kde.plasma.icontasks` como
   dock inferior. `com.dylanos.dock` es un plasmoid alternativo disponible pero no fijo.
4. **Identidad visual**: `branding/` + `themes/` (aurorae, SDDM, Plymouth, GRUB, GTK,
   color-schemes, look-and-feel).

## 2. Ventanas y KWin (ciclo de vida)

- **Apps DylanOS**: ventanas `Qt.FramelessWindowHint` con controles integrados en el
  frontend (semáforos cerrar/minimizar/maximizar a la izquierda + `startSystemMove()` para
  arrastrar). Ninguna app DylanOS muestra la decoración tradicional. La identidad de cada
  ventana se fija con `QGuiApplication::setDesktopFileName("<id>")` (Wayland app_id) y
  `StartupWMClass` (X11); el `.desktop` de cada app usa el MISMO id (`org.dylanos.*`).
- **Apps de terceros** (Firefox, Konsole, Kate…): decoración SSD de KWin con el tema
  **Aurorae DylanOS-Crimson** (regenerable: `python3 scripts/lib/generate-theme.py aurorae`):
  marco negro `#0f0f11` con esquinas redondeadas, título tenue centrado y botones semáforo
  a la izquierda (`kwinrc`: `ButtonsOnLeft=XIA`). No existe banda gris de decoración.
- **Barra superior (menú)**: panel Plasma con `hiding=letwindowscover` — KWin cubre la
  barra solo con ventanas a **pantalla completa real** (integración con el gestor de
  ventanas, sin temporizadores ni heurísticas de tamaño). Ventanas maximizadas NO la cubren.
- **Dock inferior**: panel flotante `dodgewindows` con icontasks centrado.

## 3. DylanOS Explorer (apps/dylanos-explorer)

Único explorador de archivos del sistema. Motor = **KIO de KDE** (el mismo de Dolphin):
`KDirLister` (incluye `trash:/`, `remote:/`, `smb:/`, `mtp:/`), `KFilePlacesModel` +
montaje Solid, papelera con deshacer (`KIO::FileUndoManager`, Ctrl+Z), apertura con
`KIO::OpenUrlJob`. Operaciones reales en `src/services/FileOperations.cpp` (puro Qt Core,
sin shell): crear carpeta, **crear archivo**, renombrar, copiar/mover con progreso y
cancelación, papelera (estándar freedesktop con `.trashinfo`), restaurar, vaciar,
protección de rutas del sistema. El paquete `dolphin` no se envía: `build.sh` lo purga
(entra como dependencia del metapaquete `kde-plasma-desktop`).

QA: `dylanos-explorer --screenshot out.png --size 1384x805 [--path dir]` (offscreen en el
chroot, con DBus); tests C++ reales en `tests/tst_fileoperations.cpp` vía ctest.

## 4. DylanOS Configuration (apps/dylanos-configuration)

Centro de configuración **único**. 16 páginas QML del prototipo aprobado sobre
`SystemService` (C++), que usa las herramientas reales de KDE/Linux: `kcmshell6`
(módulos KCM nativos), `plasma-apply-*`, `nmcli`, `pactl`, `bluetoothctl`,
`powerprofilesctl`, `timedatectl`, `/proc`-`/sys`, QSettings/KConfig. No hay simulaciones.
Los centros duplicados (systemsettings, kinfocenter, ajustes de otros DE) se ocultan con
`NoDisplay` en `scripts/stage.py` (el paquete `systemsettings` permanece: aporta
`kcmshell6`). Notas QML críticas: `Qt` parsea colores de 8 dígitos como `#AARRGGBB`, no
`#RRGGBBAA` (ese malentendido causó la pantalla negra de la 1.0 beta); en Items hijos,
`state` sin calificar resuelve a la propiedad integrada `Item.state` — usar `root.state`.

## 5. Temas GTK y Qt

- **GTK**: `themes/gtk/DylanOS-Crimson` y `-Light` (GTK3 + GTK4, CSS completo: menús,
  botones, campos, listas, scrollbars, diálogos, estados hover/focus/active/disabled,
  `windowcontrols` semáforo). Se aplican vía `etc/skel/.config/gtk-{3,4}.settings.ini`
  (`gtk-theme-name`) y se sincronizan con `kde-config-gtk-style`. Validación de errores
  de CSS: `GTK_THEME=DylanOS-Crimson zenity` / `nautilus` y comprobar stderr.
- **Qt/KDE**: color-schemes DylanOS{Dark,Light}, aurorae, look-and-feel `org.dylanos.crimson`
  (layout, splash, defaults). Las apps Qt NO usan el tema GTK: usan el esquema de colores KDE.
- La DylanOS Store mantiene su identidad aprobada y no se re-tematiza desde fuera.

## 6. Paquetes y decisiones de empaquetado

- `packages/default`: base + KDE + apps predeterminadas. **Sin `dolphin` ni `kcalc`**
  (Explorer y `dylanos-calculator` son los oficiales; el build los purga para chroots
  reutilizados). `systemsettings` se conserva (provee `kcmshell6`) pero oculto del menú.
- `packages/development`: incluye **Visual Studio Code** (`code`) desde el repo apt
  oficial de Microsoft (`packages.microsoft.com/repos/vscode`, suite `stable`, keyring
  propio). VSCodium fue retirado (icono incorrecto, fuente no legítima); `setup-repos.sh`
  es idempotente y borra el repo antiguo. La licencia del binario es la de Microsoft (el
  fuente "Code - OSS" es MIT); véase `docs/licenses/assets.md`.
- KWallet se mantiene: `plasma-nm` lo usa para guardar credenciales Wi-Fi (servicio
  requerido por Plasma); no se elimina por nombre.
- El ISO compila las apps nativas dentro del chroot y purga los `-dev` exclusivos al final.

## 7. Compilación, instalación y QA

    bash scripts/build.sh            # debootstrap + apt + stage + builds (chroot aislado)
    bash scripts/iso.sh              # squashfs + GRUB → DylanOS-1.0-beta-amd64.iso
    bash scripts/test_QEMU.sh        # VM con la ISO (KVM o TCG)
    DYLANOS_PYTHON=/tmp/opencode/venv/bin/python bash scripts/check.sh   # QA total

`check.sh` valida sintaxis bash + shellcheck, `test_packages.sh`, unittest completo por
módulo, `compileall`, staging con `desktop-file-validate` y la carga QML offscreen de las
6 páginas del workspace. QA adicionales: capturas offscreen de las 16 páginas de
Configuration (`--screenshot`), Test Greeter de SDDM con captura opt-in
(`theme.conf: screenshot=<ruta>`) y métricas de fidelidad en `artifacts/sddm-qa/`.

## 8. Diagnóstico rápido

- **App QML en negro**: revisar colores de 8 dígitos (orden `#AARRGGBB`) y ventana
  transparente sin contenido opaco detrás.
- **"Type X unavailable"**: el componente no está en `QML_FILES` del `qt_add_qml_module`,
  o redefine una propiedad FINAL (p. ej. `dim` de Popup).
- **"Unable to assign [undefined] to bool"**: binding sobre claves ausentes de un mapa
  (inicializar el `var` y devolver defaults desde C++) o `state` sin calificar.
- **App sin icono correcto en el dock**: `setDesktopFileName` debe coincidir con el nombre
  del `.desktop` (sin extensión) en Wayland.
- **SDDM en negro/no carga**: `sddm-greeter --test-mode --theme <ruta>` con
  `QT_QPA_PLATFORM=offscreen` y leer stderr (ReferenceError/TypeError).
- **Boot hang**: `docs/auditoria-boot-hang-initramfs.md` y `docs/solucion-boot-hang-y-grub.md`.

## 9. Limitaciones y pendientes

- La sesión live arranca en X11 (`plasmax11`) por compatibilidad con VMs sin GPU; el
  sistema instalado también soporta Wayland (los ids de app ya son correctos en ambos).
- La integración KCM de Configuration abre módulos nativos con `kcmshell6`; no re-implementa
  cada módulo en QML (decisión: reutilizar el motor de KDE con UI propia DylanOS).
- Las tarjetas del SDDM (clima, reproducción, recordatorios) son contenido de referencia:
  un greeter no tiene acceso a esos datos; reloj, calendario y usuarios son reales.
- `apps/archivos/` es un prototipo histórico que no se envía en el ISO.

## 10. Referencias

- Mapa operativo para agentes IA: `AGENTS.md` (memoria persistente, actualizarla SIEMPRE).
- Diseños aprobados: `previews/` (la referencia del SDDM es
  `previews/pantalla de bloqueo/sddm_preview.png`).
- Licencias y procedencia de recursos: `docs/licenses/assets.md`.
