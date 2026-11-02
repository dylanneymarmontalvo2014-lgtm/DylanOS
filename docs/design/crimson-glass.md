# Crimson Glass — diseño técnico

## Intención

Crimson Glass es la capa visual global de DylanOS Crimson 1.0. Traduce la
referencia de vidrio líquido a los mecanismos nativos de Plasma 6, KWin, Qt y
GTK, sin inyectar código en aplicaciones de terceros ni ocultar las
limitaciones de cada toolkit.

La referencia de vídeo muestra cinco rasgos que deben conservarse:

1. superficies de vidrio con espesor aparente, no simples capas con opacidad;
2. borde especular fino y más luminoso en la parte superior;
3. desenfoque y refracción aparente del contenido que queda detrás;
4. sombras de contacto suaves que separan las capas;
5. respuesta breve y elástica en controles, sin movimiento continuo.

La adaptación DylanOS sustituye la paleta blanca de la referencia por negro
profundo, acento Crimson `#DC143C`, texto blanco y reflejos `#ff5274`. La
refracción física se simula solo en componentes propios. Las ventanas de
terceros reciben desenfoque, transparencia, decoración y animaciones cuando
KWin y la aplicación los admiten.

## Arquitectura comprobada

- Base: Debian 13, Plasma/KWin 6.3.6 y Qt 6.8 en el chroot de compilación.
- Sesión live: X11 por compatibilidad con máquinas virtuales; Wayland está
  disponible en instalaciones normales.
- Compositor: KWin, con los efectos nativos `blur`, `contrast`, `glide`,
  `slide`, `slidingpopups`, `translucency`, `scale` y `windowview` instalados.
- Escritorio: tema Plasma `DylanOS-Crimson`, look-and-feel
  `org.dylanos.crimson`, panel superior y dock inferior translúcidos.
- Ventanas de terceros: decoración Aurorae `DylanOS-Crimson`.
- Aplicaciones propias: Qt/QML frameless; Configuration expone `SystemService`
  y es el único centro de configuración.
- Persistencia actual: ficheros XDG bajo `~/.config`, configuración KDE y
  preferencias GTK 3/4.

## Diseño por capas

### 1. Motor de configuración

`CrimsonGlassService` vive dentro de DylanOS Configuration y se expone a QML
como `CrimsonGlass`. No se crea una segunda aplicación ni un daemon.

Responsabilidades:

- cargar valores predeterminados y preferencias desde
  `~/.config/dylanos/crimson-glass.conf`;
- validar tipos, rangos y colores antes de persistir;
- detectar sesión, compositor, efecto blur, renderizado por software y soporte
  de animaciones;
- calcular los efectos efectivos cuando está activo el modo de bajo consumo;
- aplicar cambios mediante ficheros XDG/KDE y D-Bus de sesión;
- conservar y restaurar únicamente las claves que Crimson Glass modifica;
- exponer un informe legible de efectos activos y motivos de degradación.

Un autostart XDG ejecuta
`dylanos-configuration --apply-crimson-glass --headless` al iniciar sesión. El
proceso aplica la configuración y termina; no queda residente.

### 2. Integración KWin

Se usan claves presentes en KWin 6.3.6:

- `[Plugins] blurEnabled`, `contrastEnabled`, `glideEnabled`,
  `slidingpopupsEnabled` y `translucencyEnabled`;
- `[Effect-blur] BlurStrength` (0–15) y `NoiseStrength`;
- `[Effect-translucency] MoveResize`, `Dialogs`, `Inactive`, `Menus` y sus
  variantes;
- `[Effect-glide] Duration` y `[Effect-slidingpopups] SlideInTime` /
  `SlideOutTime`.

Después de escribir se llama a `org.kde.KWin` por D-Bus para reconfigurar KWin
y los efectos disponibles. Si KWin o D-Bus no están activos, los valores quedan
persistidos y el informe marca que se aplicarán al iniciar una sesión Plasma.

No se activa translucidez agresiva sobre ventanas activas: reduce legibilidad y
puede exponer contenido subyacente. Se limita a menús, diálogos, movimiento y
ventanas inactivas, con mínimos seguros.

### 3. Tema Plasma y shell

Se instala `DylanOS-Crimson-Glass` como tema Plasma derivado del tema oficial.
Sus paneles y diálogos incluyen:

- relleno negro translúcido;
- borde Crimson exterior y línea especular blanca superior;
- gradiente corto para simular espesor;
- margen de sombra integrado en los SVG cuando Plasma lo permita.

El servicio genera una copia por usuario para reflejar transparencia, borde,
reflejo, sombra y radio sin escribir en `/usr/share`. La API de paneles de
Plasma solo ofrece opacidad discreta (`opaque`, `adaptive`, `translucent`), por
lo que la transparencia independiente de panel y dock se traduce a esos estados
y el valor continuo modifica el material del tema.

### 4. Decoraciones de ventanas

Aurorae aporta el marco de aplicaciones con decoración del servidor. El perfil
Glass usa superficies negras translúcidas, borde activo Crimson e inactivo
neutro. El radio configurable se aplica a los recursos generados cuando la
decoración es Aurorae. Las aplicaciones con decoración propia conservan su
interfaz; KWin sigue aportando las capacidades externas disponibles.

### 5. Adaptadores de aplicaciones

| Tecnología | Integración segura | Límite real |
|---|---|---|
| Qt/KDE | esquema DylanOS, acento, tema Plasma, Aurorae y KWin | una app puede dibujar toda su ventana |
| GTK 3/4 | temas DylanOS Crimson, preferencia oscuro/claro y KWin | libadwaita puede restringir CSS externo |
| Electron/Chromium | portal de color, GTK cuando se respeta y efectos KWin | la UI web interna no se fuerza |
| Java/Swing | decoración KWin y preferencia de sistema | no se inyectan opciones JVM globales |
| X11 | decoración/efectos KWin cuando la ventana es gestionada | blur depende de región y compositor |
| Wayland | decoración del servidor cuando se negocia y efectos KWin | CSD puede ignorar Aurorae |
| Apps DylanOS | tokens QML y componentes Glass propios | cambios internos requieren migración por app |

### 6. DylanOS Configuration

La ruta es `Personalización → Crimson Glass`; también está disponible con
`--page crimson-glass` y desde la búsqueda.

La página contiene:

- estado principal y perfil visual;
- intensidad de cristal, transparencia, blur, reflejo, sombra y radio;
- acento y modo oscuro/claro/automático;
- panel, dock, menús, ventanas, blur, animaciones, duración, extras y bajo
  consumo;
- tarjeta de capacidades con sesión, compositor, backend y estado por efecto;
- acciones `Aplicar`, `Detectar de nuevo`, `Restaurar valores` y
  `Recuperar configuración anterior`.

Los controles escriben preferencias reales. Los deslizadores se aplican con un
retardo corto para evitar reconfigurar KWin por cada píxel del arrastre.

## Rendimiento y degradación

- Con renderizado `llvmpipe`, `softpipe`, backend software o blur no soportado,
  el blur se desactiva y se usa un material oscuro más opaco.
- Bajo consumo desactiva blur/contraste, reduce transparencias y limita las
  animaciones; no crea un proceso permanente.
- Si el factor de animación KDE está a cero, se respeta como reducción de
  movimiento y no se activan transiciones.
- Todos los materiales mantienen una opacidad mínima para que texto, selección
  y controles sigan siendo legibles.
- Un fallo D-Bus no invalida la configuración persistida ni deja ventanas
  invisibles.

## Respaldo y recuperación

Antes de la primera aplicación se guarda en
`~/.local/state/dylanos/crimson-glass/backup.json` la presencia y el valor de
cada clave tocada. La restauración es por clave: no reemplaza completos
`kwinrc`, `plasmarc`, `kdeglobals` ni los ajustes GTK y no borra otros cambios
del usuario.

La copia generada del tema vive bajo `~/.local/share/plasma/desktoptheme` y se
puede regenerar. Desactivar restaura las claves anteriores; si la sesión Plasma
no está disponible, la restauración se completa en el siguiente inicio.

## Verificación

1. pruebas unitarias del servicio: defaults, validación, persistencia, respaldo,
   restauración y cálculo de degradación;
2. pruebas de staging: tema, autostart, recursos y configuración predeterminada;
3. humo QML de `--page crimson-glass` en modo offscreen, sin stderr;
4. comprobación del chroot con Plasma/KWin 6.3.6;
5. captura de Configuration y revisión visual;
6. QA general `scripts/check.sh`;
7. prueba manual/QEMU de X11 y, cuando haya GPU disponible, Wayland.

## Límites que no se deben sobreprometer

- KWin desenfoca únicamente superficies que declaran una región de blur o
  elementos del shell que la proporcionan; no convierte el interior opaco de
  cualquier aplicación en vidrio.
- Electron, Chromium, Java y apps con CSD pueden ignorar el tema interno.
- La refracción geométrica del vídeo no existe como efecto global seguro en
  KWin 6.3.6. Se imita mediante borde, gradiente, blur y movimiento en
  componentes propios.
- La validación visual completa de compositor exige una sesión gráfica real;
  las pruebas offscreen verifican carga, persistencia y ausencia de errores,
  pero no prueban el render final de KWin.
