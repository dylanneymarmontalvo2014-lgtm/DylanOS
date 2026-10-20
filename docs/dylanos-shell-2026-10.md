# DylanOS Shell — SDDM, escritorio y Centro de Control (octubre 2026)

Registro de la implementación de DylanOS Shell a partir de las referencias de
`previews/DylanOS shell/` y de la corrección del arranque de DylanOS Store.

## 1. Qué se implementó

### SDDM (`themes/sddm/DylanOS-Crimson/`)
- `Main.qml` reescrito replicando `sddm_preview.png`: barra superior (logo +
  wordmark, indicadores, reloj 12 h), bloque central ("Bloqueado", reloj
  metálico, fecha, divisor carmesí), pista de huella inferior, botón de
  apagado y selector de sesión reales.
- Componentes en `components/`: `SideCard`, `WeatherCard`, `EventCard`,
  `MediaCard`, `SystemCard`, `CalendarCard` (calendario REAL del mes en curso,
  navegable), `RemindersCard`, `ShortcutsCard`.
- Iconos SVG propios en `images/` y `logo.png` (marca DylanOS) dentro del tema.
- Autenticación real: cualquier tecla o clic revela el campo de contraseña y
  llama a `sddm.login(usuario, contraseña, sesión)`; estado de error y
  "Iniciando sesión…" incluidos. `theme.conf` (fondo) NO cambió: los fondos de
  pantalla se conservan intactos.
- Limitación declarada: un greeter no tiene acceso a clima, música, batería ni
  notificaciones; esas tarjetas muestran contenido de referencia estático, tal
  como aparece en el preview. Relojes y calendario sí son reales.

### Escritorio (layout `org.kde.plasma.desktop-layout.js`)
- Barra superior: Kickoff (logo DylanOS) + app activa + menús de la app +
  `com.dylanos.search` (lupa que lanza `dylanos-spotlight`) + bandeja del
  sistema + `com.dylanos.controlcenter` + reloj 12 h con fecha
  (`ddd dd 'de' MMM`, `use24hFormat=1`).
- Dock inferior: lanzadores fijados + papelera (`org.kde.plasma.trash`) al
  final, como en el preview.
- Los widgets del escritorio de los previews (clima, calendario, recordatorios
  sobre el fondo) NO se implementan: así lo exige la especificación temporal.

### Centro de Control (`apps/dylanos-control-center/`)
- Plasmoid `com.dylanos.controlcenter`: compact representation (campana con
  badge carmesí de notificaciones reales vía NotificationManager) y popup con
  Notificaciones + Centro de control (ya conectados a datos reales: nmcli,
  BluezQt, pactl, PowerDevil, MPRIS, `plasma-apply-colorscheme`).
- Accesos secundarios ahora funcionales vía `kcmshell6`: AirDrop→KDE Connect
  (`kcm_kdeconnect`), Proyectar (`kcm_kscreen`), Ahorro de energía
  (`powerdevilprofilesconfig`). "Configuración rápida" abre Ajustes DylanOS
  (`dylanos --page settings`).
- BUG de integración corregido: el plasmoid existía pero `scripts/stage.py`
  nunca lo instalaba. Ahora se instala en
  `/usr/share/plasma/plasmoids/com.dylanos.controlcenter` y el layout lo añade
  a la barra superior.

### Nuevo plasmoid `apps/com.dylanos.search`
- Botón de lupa de la barra superior; lanza `dylanos-spotlight` con el motor
  `executable` de Plasma5Support.

## 2. DylanOS Store: causa raíz del "no abre" y corrección

- Diagnóstico: en `main.cpp` la ventana solo se creaba cuando el catálogo
  estaba listo (`catalogReady` → `engine.loadFromModule`). Si la
  inicialización de los backends (PackageKit/AppStream) tardaba o se quedaba
  esperaba, la app corría sin ventana: al hacer clic en el lanzador no se
  abría nada. Además el reloj de seguridad de 20 s era la única vía de escape.
- Corrección (ya presente como cambio local, ahora validada y conservada): la
  ventana se crea INMEDIATAMENTE (`engine.loadFromModule` al arrancar) y el
  catálogo se rellena de forma reactiva (`Store.shelfVersion`) cuando llegan
  los datos. `KDBusService` usa `NoExitOnFailure` para que el registro DBus
  único nunca impida abrir la ventana.
- Verificación: build completo en el chroot (`cmake + ninja + ctest`: 3/3
  tests) y arranque real en el chroot: los logs muestran el motor QML cargando
  `DylanOS Main`, el scene graph creando la ventana ("Loading backend
  software") y el catálogo aplicándose desde la semilla y refrescándose del
  repositorio remoto.
- QA de captura: se instrumentó `--screenshot` con mensajes `screenshot:
  capturing/grabbed` para depurar la captura en offscreen.

## 3. Compilación e instalación

- La distro compila la tienda en `scripts/build.sh` (chroot, cmake+ninja,
  ctest, install). Para iterar rápido existe el chroot de pruebas
  `work/discover-build`.
- Staging idempotente: `python3 scripts/stage.py <root>` instala los plasmoids
  `com.dylanos.search` y `com.dylanos.controlcenter`, el tema SDDM completo
  (con `components/`, `images/` y `logo.png`) y el layout nuevo.

## 4. QA

```bash
DYLANOS_PYTHON=<venv con PySide6> bash scripts/check.sh
```
- `test_staging.py` ampliado: exige search/controlcenter staged, el layout con
  search + controlcenter + trash + reloj 12 h, y el greeter SDDM con
  `sddm.login` + `revealLogin` + componentes.
- QML validado con `qmllint` (0 errores) y carga real del greeter con
  `qmltestrunner` (Loader Ready; solo avisos esperables de las propiedades de
  contexto `sddm/config/userModel/sessionModel`, que existen en el greeter).

## 5. Recuperación

- SDDM: el tema anterior (`DylanOS-SDDM`, fork de Apple-Sonoma-v2) sigue
  instalado en `/usr/share/sddm/themes/DylanOS-SDDM`. Para revertir:
  `sudo sed -i 's/^Current=DylanOS-Crimson/Current=DylanOS-SDDM/' /etc/sddm.conf.d/10-dylanos.conf`.
- Layout del escritorio: revertir con el archivo en git
  (`themes/lookandfeel/org.dylanos.crimson/contents/layouts/...`); los paneles
  existentes de un usuario no se tocan en re-layouts de Plasma.
- Fondos de pantalla: sin cambios (verificado con `test_staging.py`, que
  compara bytes contra `branding/wallpapers/`).
