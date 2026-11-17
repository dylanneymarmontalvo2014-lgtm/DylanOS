# DylanOS Widgets

Sistema de widgets de escritorio de DylanOS Crimson, con el acabado Crimson
Glass. Se apoya en los plasmoides nativos de Plasma 6: no hay un compositor
ni un proceso propio. La auditoría y las decisiones de arquitectura están en
[widgets-auditoria.md](widgets-auditoria.md).

## Regla de visibilidad: Live USB frente a sistema instalado

- **Sesión live (USB, sin instalar): cero widgets.** El escritorio queda
  limpio.
- **Sistema instalado, primer inicio de sesión de cada usuario: exactamente
  tres widgets**, una sola vez:

  ```
  ┌─────────┐ ┌─────────┐
  │  Reloj  │ │Calendario│     small (1x1) + small (1x1)
  └─────────┘ └─────────┘
  ┌───────────────────────┐
  │         Clima         │     medium-wide (2x1): doble de ancho,
  └───────────────────────┘     misma altura que un widget normal
  ```

Después el usuario puede quitar, mover o cambiar esos widgets libremente: el
layout no se vuelve a aplicar nunca.

### Cómo se distingue live de instalado

`layout.js` **no** crea widgets: se ejecuta también en live (perfil nuevo) y
el squashfs es el mismo en ambos casos, así que un marcador en la imagen
tampoco serviría. La decisión se toma en tiempo de sesión, en
`/usr/lib/dylanos/dylanos-widget-layout`:

1. si existe el medio live (`/run/live/medium` o
   `/lib/live/mount/medium`, las mismas rutas que usa el instalador) → sale
   sin hacer nada;
2. si el usuario ya tiene la marca en
   `~/.local/state/dylanos/widgets/layout-applied.json` → sale;
3. si no, crea los tres widgets vía `org.kde.PlasmaShell.evaluateScript` con
   `addWidget(tipo, x, y, w, h)` y escribe la marca.

El autostart `org.dylanos.widgets.desktop` lo ejecuta con
`X-KDE-autostart-after=panel`. Si `plasmashell` no responde, **no** se escribe
la marca: el siguiente inicio lo reintenta.

## Retícula y clases de tamaño

El lado de celda es `clamp(alto_pantalla / 6, 120, 190)` px y el margen es
`celda / 3`. Un widget «normal» es cuadrado: ancho = alto = celda.

| Clase | Celdas | Uso |
|---|---|---|
| `small` | 1×1 | cuadrado normal |
| `medium-wide` | 2×1 | doble de ancho, misma altura (Clima) |
| `medium-tall` | 1×2 | más alto que ancho |
| `large` | 2×2 | cuadrado grande |
| `extra-large` | 4×2 | calendario mensual, galerías |

Cada widget declara en `supportedSizes` lo que soporta. La fórmula está
duplicada a propósito en dos sitios —`scripts/dylanos-widget-layout` y
`apps/dylanos-widgets-lib/WidgetTokens.js`— porque una la necesita Python en
el arranque y la otra QML en tiempo de ejecución;
`scripts/tests/test_widgets.py` ejecuta ambas y falla si divergen.

## Catálogo

20 widgets, definidos en `apps/dylanos-widgets/qml/WidgetCatalog.js` (fuente
única: la galería y los tests leen el mismo archivo). La galería es
`dylanos-widgets` (app QML frameless, desktop id `org.dylanos.widgets`).

Estados del catálogo:

- `ready` — datos reales disponibles en la imagen.
- `needs-pkg` — requiere un paquete que aún no está en el perfil.
- `limited` — funciona con un límite declarado, siempre visible al usuario.

Ningún widget muestra datos simulados. Si la fuente falta, la tarjeta presenta
un estado explícito; por eso el Clima sin proveedor dice «Configura tu
ubicación» en lugar de inventar una temperatura.

## Librería común

`apps/dylanos-widgets-lib/` contiene `WidgetTokens.js` (color, tipografía,
espaciado, radios, materiales y retícula), `WidgetCard.qml` (superficie Crimson
Glass) y `WidgetHeader.qml` (jerarquía de título).

Es una biblioteca JS `.pragma library` y no un singleton QML: los plasmoides
se cargan desde el sistema de archivos y un singleton exigiría un `qmldir` y
un import path real. Es el mismo patrón que ya usa
`apps/com.dylanos.dashboard` con `PomodoroClock.js`.

Cada plasmoid es autocontenido y lleva **su copia** de la librería en
`contents/ui/lib/`. Las copias son idénticas a la fuente y
`test_widgets.py` lo verifica: si divergen, dos widgets del mismo escritorio
se verían distintos.

## Crimson Glass y modo rendimiento

Los widgets no deciden si hay blur: el compositor aplica el desenfoque del
escritorio y la tarjeta solo fija relleno, borde especular y sombra
(`docs/crimson-glass.md`). Tres variantes de material: `dark`, `crimson` y
`light`. En modo rendimiento la opacidad sube a 0,92 y la sombra desaparece.

Ningún widget declara un color literal: todos salen de `WidgetTokens.js`, que
usa la paleta oficial (`#DC143C`, `#0A0A0A`, `#FFFFFF`, `#1A1A1A`, `#B3B3B3`).
Los valores con alfa van en orden `#AARRGGBB`, no `#RRGGBBAA`.

## Verificación

```bash
python3 -m unittest scripts.tests.test_widgets      # catálogo, retícula, live/instalado
python3 -m unittest scripts.tests.test_staging      # el payload no lleva layout
python3 scripts/dylanos-widget-layout --print-layout --screen-height 800
```

`test_widgets.py` cubre los requisitos que pueden romperse en silencio: 20
widgets con contrato completo, el Clima exactamente al doble de ancho y misma
altura, detección live, aplicación única por usuario, y que un fallo de DBus
no marque el layout como aplicado.

La carga QML real de los tres plasmoides requiere Plasma
(`scripts/tests/test_plasmoid_runtime.sh` en el chroot). La galería se
instancia en `scripts/check.sh` con PySide6.

## Límites conocidos

- **Clima**: la consulta al proveedor de Plasma no está implementada; la
  tarjeta muestra el estado explícito y el botón de configuración real. El
  punto de integración es el engine `weather` de plasma5support.
- **Portapapeles**: sin backend de historial en la imagen, solo el contenido
  actual.
- **Próximo evento**: lee un `.ics` local elegido por el usuario; la imagen no
  incluye calendario de sistema.
- **Fotos**: requiere `qml6-module-qt-labs-folderlistmodel`.
- **Stacks y modo edición tipo jiggle**: no van en 1.0. El redimensionado usa
  el modo de edición de Plasma, no una réplica del gesto de macOS; la
  geometría libre de Plasma no hace snapping a la retícula (se acota con
  `minimumWidth`/`minimumHeight`).
## Los 20 widgets y su fuente de datos

Los 20 están implementados como paquete propio. `test_widgets.py` exige que
cada entrada del catálogo tenga su paquete, que ninguno quede bloqueado por un
paquete ausente y que todos usen los tokens compartidos.

| Widget | Fuente real |
|---|---|
| Reloj | reloj del sistema |
| Calendario | fecha del sistema |
| Clima | proveedor de Plasma (sin configurar: estado explícito) |
| Batería | `/sys/class/power_supply` |
| CPU y RAM | `/proc/stat` y `/proc/meminfo` |
| Red y Wi-Fi | `nmcli` (NetworkManager) |
| Notas | `Plasmoid.configuration` |
| Reproductor | `playerctl` (MPRIS) |
| Calculadora | evaluador propio sin `eval` |
| Accesos directos | `gtk-launch` con el id `.desktop` |
| Fotos | `FolderListModel` sobre una carpeta local |
| Captura rápida | `spectacle` y el recuento en `~/Imágenes` |
| Portapapeles | `xclip` (X11) o `wl-paste` |
| Tareas | `Plasmoid.configuration` |
| Reloj mundial | `Intl` del motor Qt (zoneinfo) |
| Pomodoro | temporizador sobre la hora del sistema |
| Disco | `df -B1` |
| Actualizaciones | `apt-get -s upgrade` (simulación, no instala) |
| DylanOS Info | `os-release`, `/proc/cpuinfo`, `/proc/meminfo`, `uname -r` |
| Próximo evento | archivo `.ics` local elegido por el usuario |

### Datos verificables, no supuestos

Las funciones que interpretan datos (`WidgetData.js`) y el evaluador
(`WidgetCalc.js`) son bibliotecas `.pragma library` sin dependencias de QML,
así que se ejecutan con `node` y se prueban con datos reales en
`test_widgets.py`: contadores de `/proc/stat` sin contar `guest` dos veces,
deltas incoherentes que se descartan, RAM ajustada a potencia de dos, `df`
malformado que no produce cifras, porcentaje de UPower en ambas escalas, y un
evaluador que rechaza `9**99999999`, `1/0`, `alert(1)` y `__proto__`.

### Dependencias añadidas al perfil base

`qml6-module-qt-labs-folderlistmodel` (Fotos) y `xclip` (Portapapeles en X11).
Ambas verificadas en Debian 13 y cubiertas por `test_packages.sh`.

## Revisión visual real y defectos corregidos

Los widgets se renderizaron a PNG con `QQuickView` (offscreen) para inspeccionar
el resultado, no solo el código. Las capturas viven en `artifacts/widgets-qa/`.
Defectos que solo aparecieron al mirar el render:

| Defecto | Causa real | Corrección |
|---|---|---|
| El día 30 se salía de la tarjeta | La `Column` no recorta y 6 filas × 12 px desbordaban los ~69 px útiles de un cuadrado de 133 px | El alto de fila se reparte entre las filas que el mes necesita, con margen reducido en widgets pequeños |
| Cabecera «novie…» cortada | El nombre completo del mes no cabe junto a los botones en 133 px | Se abrevia a tres letras y, si no cabe, se omite el año |
| Accesos con iniciales repetidas «E, N, T, T» | Explorer/Tienda/Terminal comparten inicial | `Kirigami.Icon` con el icono real del tema; respaldo con dos letras |
| Reloj mundial mostraba la misma hora en Madrid y UTC | `Intl` **no existe** en el motor QML (`typeof Intl === "undefined"`) | Se descartó Intl; ver abajo |
| Reloj mundial con «—» siempre | `TZInfo` tampoco está disponible en todos los Qt (`TZInfo is not defined`) | Se resolvió con `date` del sistema |
| Reloj mundial con hora falsa para zona inexistente | `TZ=ZonaInvalida date` **no falla**: cae a UTC en silencio | La zona se valida contra `/usr/share/zoneinfo` antes de usarla |
| Reloj mundial pisaba horas entre zonas | Un índice compartido se sobrescribía con respuestas asíncronas | Una sola consulta devuelve todas las horas en orden |

### Acabado premium

Sobre esas correcciones se aplicó un pulido de material y tipografía que afecta
a los 20 widgets de una vez, porque vive en `WidgetCard` y en los tokens:

- **Vidrio con volumen real.** El relleno era plano y se leía como un hueco
  negro sobre el fondo. Ahora hay un degradado vertical (`materialFillTop` →
  `materialFill`), el reflejo especular superior y un halo interior de 1 px. En
  modo rendimiento el degradado se aplana para no perder contraste.
- **Jerarquía del Reloj.** Segundos en su propia línea, pequeños y en Crimson:
  al lado de la hora empujaban el texto fuera de la tarjeta en 133 px. Escala
  verificada en 1×1 y 2×2.
- **Anchos explícitos.** Las columnas centradas sin `width` adoptaban el ancho
  de su hijo más ancho; por eso «No se pudo consultar APT» desbordaba la
  tarjeta del widget de Actualizaciones. Ahora el texto se ajusta en dos líneas.
- **Títulos que caben.** «Actualizaciones» no entra en 133 px: se abrevia a
  «Mejoras» por debajo de 180 px, sin mezclar idiomas.

Dos hallazgos que **no** eran defectos del widget, comprobados antes de tocar nada:

- La fecha del Reloj aparecía en inglés («MON 16 NOV») solo en el harness, que
  corre sin locale. Con el locale del sistema (`es_CO`/`es_ES`) Qt devuelve
  «lun 16 nov»; el ISO fija `locales=es_ES.UTF-8`.
- Los widgets de datos muestran «—» o «no disponible» en las capturas porque
  `P5Support.DataSource` no ejecuta comandos fuera de Plasma. Es el estado
  explícito correcto, no un fallo: en sesión real leen `/proc`, `nmcli`, etc.

### Límite de esta verificación

El render prueba el QML y su maquetación; **no** prueba Plasma real. La carga
bajo `plasmashell` y el `evaluateScript` del layout inicial siguen pendientes de
un chroot con Plasma 6.3 (`scripts/tests/test_plasmoid_runtime.sh`), que este
entorno no puede construir: no hay `debootstrap` ni el binario `chroot`, y `sudo`
requiere contraseña interactiva.
