# DylanOS Shell

The first-run Plasma desktop layout adds the DylanOS dashboard to each desktop using Plasma's positioned `Containment.addWidget` scripting API. It provides a live clock, a navigable month calendar, and local memory, CPU-usage, filesystem-capacity, and uptime readings from `/proc` and `df`; it intentionally has no fabricated weather, events, reminders, or remote-service data. Like the rest of the initial layout, this applies to new profiles and does not replace an existing user's panels or desktop widgets.

The Control Center's Do Not Disturb toggle now uses Plasma's public `NotificationManager.Settings` API. A user-initiated toggle inhibits notifications for eight hours and can be cleared from the same control. An application-owned inhibition is shown as such and is not overridden. The notification list continues to display the real Plasma notification model, including while Do Not Disturb is active. The compact badge shows the number of current notifications, not an unread count. The secondary action opens KDE Connect by its proper name, not the unrelated AirDrop brand.

## DylanOS Console

DylanOS Console es la única terminal visible del sistema. Usa Kitty como motor y el
lanzador estable `dylanos-console`, con app id `org.dylanos.console`, nombre e icono
propios. El staging oculta los lanzadores genéricos de Kitty y elimina los restos de
Konsole; el build purga su paquete si reaparece como recomendación de Plasma.

La configuración compartida vive en `configs/kitty/kitty.conf`: JetBrains Mono, paleta
Crimson, fondo `#0A0A0A` con opacidad 0,40 y blur 24 inspirado en la consola de referencia,
pestañas minimalistas y 50.000 líneas de
historial. `dylanos-console --directory <ruta>` conserva el flujo de abrir un proyecto
directamente en su carpeta.

Neofetch sustituye a Fastfetch y se ejecuta al abrir el primer Bash interactivo. Debian
13 ya no distribuye el paquete original, por lo que DylanOS instala `neowofetch` —su fork
compatible y mantenido— detrás del nombre estable `/usr/bin/neofetch`. El backend `kitty`
dibuja la imagen PNG real de `branding/logo.png`, no arte ASCII; el panel usa etiquetas
en español, separador con nombre y la paleta oficial. ImageMagick prepara la imagen.

El recomendador Bash consulta primero el historial reciente y después los comandos
disponibles. Sugiere el sufijo y lo incorpora a la línea solo cuando el usuario pulsa Tab
o flecha derecha. Si no hay sugerencia, Tab conserva el completado de comandos/archivos.
El texto no se repinta mientras se escribe: los bindings por carácter encadenaban macros
de Readline ("maximum macro execution nesting level exceeded") y bloqueaban cualquier
comando. El módulo solo registra atajos Readline en sesiones interactivas y se prueba
ejecutando una recomendación real y su aceptación.


## Seguimiento de la identidad visual y la optimización

- **Dashboard (actualización 2026-10-23):** se amplió el panel a 500 × 360 para alojar las métricas añadidas y se agregaron lecturas reales de uso de CPU desde las diferencias de contadores de `/proc/stat` y espacio usado/total del filesystem raíz mediante `df -B1`. CPU, memoria y disco usan barras carmesí; si una fuente no está disponible, se muestra un estado explícito, no un valor inventado. Se conserva el calendario, reloj y uptime.
- **Optimización de la ISO (actualización 2026-10-23):** `scripts/build.sh` instala paquetes explícitos con `--no-install-recommends` y, después de retirar Dolphin, sus plugins, KCalc y dependencias de compilación, ejecuta `apt-get autoremove --purge`. APT decide qué dependencias automáticas ya no necesita. No se eliminan apps que estén en la lista base; tampoco se cambian el fondo ni los paquetes funcionales explícitos.
- **Motivo/alcance:** evitar software recomendado no pedido y dependencias huérfanas, además de acercar el panel de estado a la referencia visual sin inventar datos. Esto puede reducir el tamaño de futuras imágenes; no se afirma un ahorro de bytes hasta construir y medir una ISO nueva.
- **Verificación requerida:** `bash scripts/tests/test_packages.sh`, `python3 -m unittest scripts.tests.test_shell_contract`, `make check`, `make build`, `make iso` y `make test-iso`. Una build automatizada no demuestra el arranque del escritorio; para eso se requiere `make qemu-test` y revisar el render real.
- **Archivos afectados:** `apps/com.dylanos.dashboard/contents/ui/main.qml` (métricas), `scripts/build.sh` (instalación/purga), `scripts/tests/test_packages.sh` y `scripts/tests/test_shell_contract.py` (regresiones) y este documento.

## Corrección de CPU del dashboard (2026-10-24)

- `apps/com.dylanos.dashboard/contents/ui/main.qml`: los contadores `guest` y `guest_nice` de `/proc/stat` ya no se suman dos veces (Linux ya los incluye en `user` y `nice`). Se descartan deltas incoherentes antes de actualizar el porcentaje para evitar mostrar una medición inválida.
- `scripts/tests/test_shell_contract.py`: regresión contractual para el ajuste de contadores guest y validación del intervalo de deltas.
- Verificación: el CI `Check beta` de `development` se ejecuta para este cambio; no es prueba de arranque ni de render gráfico en QEMU.
- No cambia el wallpaper, la configuración de Konsole ni Fastfetch.


## Widgets interactivos y refresco eficiente (2026-10-24)

- Dashboard: el calendario permite seleccionar cualquier día visible, marca
  el día actual y expone una acción «Hoy» para regresar rápidamente. La fecha
  seleccionada se presenta con formato local; no se simulan citas ni eventos.
- Centro de Control: el silencio de salida ahora usa `pactl` real. El cambio
  de tema conserva la paleta propia `DylanOSDark`/`DylanOSLight` en vez de
  reemplazarla por Breeze.
- Eficiencia: brillo/volumen se consultan cada 5 s; Wi-Fi, reproducción y tema
  cada 15 s, en lugar de lanzar toda la batería de consultas cada 2 s.
  `playerctl` se incluye en el perfil base para que los controles MPRIS no
  dependan de instalación manual.
- En esa actualización, ambos applets actualizaron sus metadatos a 0.2.0.
  Dashboard avanzó después a 0.3.0 con los indicadores gráficos documentados
  más abajo. Las pruebas de contrato y staging no sustituyen QA visual en Plasma.


## Comando `about`

En una terminal, ejecuta `about` para mostrar los nombres del archivo
`/usr/share/dylanos/MAINTAINERS.txt` en el mensaje de agradecimiento. El listado
se obtiene de los bloques `MANTENEDOR` del archivo mantenido por el proyecto;
si no hay nombres o no se puede leer, el comando informa el problema y termina
con error en vez de inventar créditos.


## Verificación del widget `about` (2026-10-24)

El comando `about` se instala como `/usr/bin/about`; imprime el texto de
agradecimiento con los nombres leídos de `/usr/share/dylanos/MAINTAINERS.txt`.
El staging copia el archivo de mantenedores y una prueba de contrato modifica
una copia temporal del archivo para comprobar que la salida refleja altas de
nombres sin editar el script. No se cambia el fichero de créditos de origen.


## Control de micrófono (2026-10-24)

El Centro de Control ahora consulta `pactl get-source-volume` y `pactl get-source-mute`
para la fuente predeterminada y permite cambiar su nivel o silenciarla con
`pactl set-source-volume` / `set-source-mute`. Si el servidor de audio no publica
una fuente de entrada, el control se deshabilita. Esto está cubierto por el
contrato estático en `test_shell_contract.py`; aún requiere prueba visual y de
hardware en Plasma para validar la interacción con distintos dispositivos.


## Indicadores visuales del Dashboard (2026-10-24)

Las métricas de RAM y del filesystem raíz presentan porcentaje más capacidad
usada; CPU conserva su porcentaje. Las tres barras Crimson animan las variaciones
entre muestras y ofrecen nombre accesible con su valor. El helper limita anchos
a 0–100% y maneja valores sin datos. Dashboard eleva el paquete a 0.3.0. La
prueba contractual verifica estas propiedades; no sustituye QA visual en Plasma.


## Estados visuales del calendario (2026-10-24)

El Dashboard 0.3.1 refuerza la fecha elegida y conserva un contorno distinto para
hoy cuando se selecciona otro día. Los nombres accesibles indican «hoy» y
«seleccionado» según corresponda; hover, selección y contorno cambian con una
transición breve. Las pruebas de contrato comprueban QML y staging, pero falta
validar percepción y foco en una sesión real de Plasma.


## Abrir Monitor del sistema desde Dashboard (2026-10-24)

Dashboard 0.4.0 incorpora el botón «Abrir Monitor del sistema», que ejecuta el
comando real `plasma-systemmonitor` mediante el motor executable de Plasma. El
paquete está en `packages/default/packages.list`. La prueba de staging y la
prueba contractual comprueban el comando, botón y dependencia; todavía falta
verificar su apertura visual en una sesión Plasma real.


## Actualización manual del Dashboard (2026-10-24)

Dashboard 0.4.1 ofrece «Actualizar» junto al estado del sistema. Llama la misma
función de lectura local que el refresco periódico de 10 segundos y muestra la
hora local de la última solicitud. No cambia las fuentes: RAM, uptime, CPU y uso
del filesystem raíz siguen viniendo de `/proc` y `df`. Las pruebas de contrato y
staging verifican la acción y la marca de hora, pero no el render en Plasma.


## Tendencia real de CPU del Dashboard (2026-10-24)

Dashboard 0.5.0 conserva hasta 24 porcentajes de CPU calculados a partir de
deltas reales de `/proc/stat` y los dibuja en una gráfica Crimson Canvas con
marcas horizontales. No se añaden valores sintéticos: con menos de dos muestras
no hay trazo. La etiqueta accesible anuncia cuántas muestras existen y el valor
actual. El refresco periódico es de unos 10 segundos; actualizar manualmente
puede añadir una lectura extra. Las pruebas de código no sustituyen la validación
del render Canvas en una sesión Plasma 6.


## Consistencia visual Crimson entre aplicaciones (2026-10-24)

Primera pasada de armonización para Configuration, Explorer y Workspace: los
tokens de acento dejan de usar rojos incompatibles con la marca y se alinean
con el crimson oficial `#DC143C`, `#FF4565` para hover/énfasis y `#A50F2E` para
presión. Botones QML de Configuration y Workspace derivan degradados de la
paleta propia del tema; los botones de Configuration interpolan el hover en
140 ms. Se conservan los acentos semánticos de las categorías de Configuración
y las opciones personalizables del usuario. GTK, Plasma, SDDM, wallpapers y
Kitty no se alteran en esta pasada. Las pruebas son estáticas y de contrato;
no equivalen a captura/render de cada aplicación en Plasma real.


## Temporizador Pomodoro local del Dashboard (2026-10-24)

Dashboard 0.6.0 aumenta la altura del widget a 470 px y añade enfoque de 25 min y descanso de 5 min, con controles para
iniciar, pausar, continuar y reiniciar, estado accesible, indicador de progreso
animado y contador de ciclos de enfoque completados. El paso de enfoque a
descanso y viceversa es manual: al terminar, el botón propone el bloque
siguiente y espera una pulsación. El tiempo restante se calcula con un deadline basado en
`Date.now()` para que el temporizador no dependa del número de ticks del
Timer; no se guardan ajustes, historial ni progreso al cerrar el widget.

**Archivos afectados:** `apps/com.dylanos.dashboard/contents/ui/main.qml`,
`apps/com.dylanos.dashboard/contents/ui/PomodoroClock.js`,
`apps/com.dylanos.dashboard/metadata.json`, documentación del applet/guía,
y pruebas de contrato y empaquetado. **Pruebas:** cálculos puros probados con
Node si está disponible, además de las suites `test_shell_contract.py` y
`test_staging.py`; no son una prueba de render gráfico en Plasma.


## Superficies glass sutiles (2026-10-24)

Dashboard 0.7.0 incorpora fondo oscuro semitransparente con un reflejo superior
leve, borde fino claro y tarjeta Pomodoro ligeramente translúcida. Centro de
Control y Notificaciones 0.3.0 dejan pasar discretamente el fondo en su panel
exterior y conservan sus tarjetas funcionales con contraste. El tema Plasma
genera sus variantes `translucent` con opacidad 0.84 para barras y diálogos,
para equilibrar transparencia y legibilidad. `BlurBehindEffect` permite que
KWin desenfoque el fondo cuando el compositor lo soporta/está activo; QML no
inventa el blur como imagen estática ni garantiza la función en equipos sin
compositor. No se cambia wallpaper, Kitty ni el tema de color personalizado.

**Archivos afectados:** `apps/com.dylanos.dashboard/contents/ui/main.qml` y
`metadata.json`; paneles QML y metadatos del Centro de Control;
`scripts/lib/generate-theme.py`; pruebas de contrato/tema/staging; guías de uso.
**Validación:** pruebas de suites estáticas, generación y staging; QA visual real
requiere una sesión Plasma 6 con composición habilitada.


## Menos memoria y actividad en segundo plano (2026-10-24)

Centro de Control 0.4.0 comparte el mismo `NotificationManager.Notifications`
entre el indicador compacto y la lista desplegable: se elimina la segunda
instancia del modelo. Los temporizadores de lectura de audio/brillo (5 s) y
Wi-Fi/tema/MPRIS (15 s) solo funcionan mientras el popup está abierto; al
abrirlo se solicita una lectura inmediata y al cerrarlo se paran. Se conserva
la actualización en tiempo real mientras el usuario usa el panel y se dejan
intactos los servicios/paquetes del sistema. Se reduce memoria auxiliar y
actividad en reposo; no se atribuye una cifra de MiB sin benchmark de una ISO
y sesión equivalentes antes/después.

**Archivos afectados:** `apps/dylanos-control-center/contents/ui/main.qml`,
`NotificationsPanel.qml`, `SystemStatus.qml`, `metadata.json`, README, guía,
contratos de shell/staging y `docs/optimization.md`. QA gráfica y memoria real
quedan pendientes de VM Plasma 6 y medición bajo la misma carga.
