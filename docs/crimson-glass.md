# Crimson Glass

Crimson Glass es el perfil visual global de DylanOS Crimson 1.0. Coordina
Plasma, KWin, las decoraciones Aurorae, los esquemas Qt/KDE y los temas GTK
desde **DylanOS Configuration → Personalización → Crimson Glass**. No inyecta
código en aplicaciones y no mantiene un proceso residente.

## Qué modifica

- instala y selecciona el tema Plasma `DylanOS-Crimson-Glass`;
- selecciona la decoración Aurorae
  `__aurorae__svg__DylanOS-Crimson-Glass` para ventanas con decoración del
  servidor;
- configura blur, contraste, translucidez y transiciones nativas de KWin;
- sincroniza el acento y el modo oscuro/claro de KDE y GTK 3/4;
- ajusta por separado el modo de opacidad del panel superior y el dock;
- genera en el perfil del usuario los SVG de paneles y diálogos con la
  opacidad, el radio, el reflejo, la sombra y el acento elegidos.

La copia dinámica vive en
`~/.local/share/plasma/desktoptheme/DylanOS-Crimson-Glass`. Sus recursos no
sobrescriben `/usr/share` y se pueden regenerar desde la página de
configuración.

## Aplicación y persistencia

Las preferencias se guardan en
`~/.config/dylanos/crimson-glass.conf`. Cada cambio en la página se aplica con
un retardo de 160 ms para no reconfigurar KWin por cada píxel durante el
arrastre. También se puede aplicar el perfil sin interfaz:

```bash
dylanos-configuration --apply-crimson-glass --headless
```

El autostart `org.dylanos.crimson-glass.desktop` ejecuta ese comando al iniciar
Plasma y termina al completar la aplicación. No queda ningún daemon.

## Degradación segura

La detección automática se actualiza antes de aplicar el perfil. Reconoce el
tipo de sesión, la presencia de KWin y sus efectos, el backend indicado por Qt
y los renderizadores de software `llvmpipe` y `softpipe`.

En renderizado por software o con el modo de bajo consumo activo:

- blur y contraste quedan desactivados;
- el material sube a una opacidad mínima del 88 %;
- las transiciones costosas de KWin quedan desactivadas;
- las aplicaciones conservan siempre contenido legible y operable.

Si `KDE_ANIMATION_DURATION_FACTOR=0` o el valor equivalente de `kdeglobals`
está activo, Crimson Glass no habilita animaciones. El usuario puede desactivar
por separado ventanas, blur, animaciones y efectos adicionales.

## Recuperación

Antes de la primera aplicación se guarda un respaldo por clave en
`~/.local/state/dylanos/crimson-glass/backup.json`. No se copian ni reemplazan
completos `kwinrc`, `plasmarc`, `kdeglobals` ni los ajustes GTK.

Para volver al estado anterior:

1. abrir **Compatibilidad**;
2. pulsar **Recuperar configuración**;
3. cerrar y volver a abrir una aplicación si su toolkit no actualiza el tema
   en caliente.

La recuperación elimina las claves que originalmente no existían y restaura
solo las que Crimson Glass administró. Desactivar el interruptor principal
ejecuta la misma restauración al aplicar. Si la interfaz gráfica no abre, se
puede cambiar `enabled=false` en el fichero de preferencias y ejecutar el
comando headless anterior.

Si una escritura falla durante la activación, el motor intenta inmediatamente
restaurar todas las claves anteriores. Cuando la ruta que causó el fallo sigue
sin ser escribible, conserva el respaldo y muestra que la recuperación quedó
incompleta para poder reintentarla después de corregir el problema.

## Compatibilidad real

| Superficie | Integración | Límite |
|---|---|---|
| Plasma 6 | tema, paneles, diálogos, opacidad y blur del compositor | cada plasmoid decide si declara región de blur |
| Qt/KDE | esquema, acento, KWin y decoración del servidor | una app puede dibujar su propio marco e interior |
| GTK 3/4 | tema Crimson Glass seguro y preferencia oscuro/claro | libadwaita puede restringir estilos externos |
| Electron/Chromium | preferencias del sistema y efectos externos de KWin | no se modifica la interfaz web interna |
| Java/Swing | marco y efectos externos gestionados por KWin | no se inyectan opciones JVM globales |
| X11/Wayland | efectos del compositor y SSD cuando la ventana los admite | CSD y superficies opacas pueden impedir blur interno |

El radio variable modifica paneles y diálogos Plasma y la previsualización.
Aurorae conserva por ahora su máscara segura de 12 px; no se promete un radio
arbitrario para aplicaciones con decoración propia. La refracción geométrica
del vídeo de referencia se simula con blur, reflejos, bordes y profundidad: KWin
6.3.6 no ofrece una refracción física global y segura.

## Verificación

Pruebas automatizadas:

```bash
cmake -S apps/dylanos-configuration -B build/config-test -GNinja -DBUILD_TESTING=ON
cmake --build build/config-test
ctest --test-dir build/config-test --output-on-failure
DYLANOS_PYTHON=/tmp/opencode/venv/bin/python bash scripts/check.sh
```

La carga de la página puede comprobarse sin compositor:

```bash
QT_QPA_PLATFORM=offscreen build/config-test/dylanos-configuration \
  --page crimson-glass --smoke
```

Las pruebas offscreen verifican QML, persistencia, generación de temas,
respaldo y degradación. No demuestran el render de blur de KWin. La validación
de compositor requiere una sesión Plasma real o la ISO en QEMU y debe probar
abrir, mover, maximizar, minimizar, cambiar de escritorio y usar diálogos tanto
con el perfil completo como con bajo consumo.

### Resultados ejecutados el 2026-11-02

- `ctest` del servicio: 1/1 objetivo aprobado en el host (Qt 6.4.2) y en el
  chroot Debian 13 (Qt 6.8.2).
- pruebas enfocadas de Configuration, staging y escritorio: aprobadas.
- carga y captura offscreen en el chroot: 17/17 rutas generaron PNG de
  1280×800; stderr total: 0 bytes.
- los cuatro CSS DylanOS-Crimson/DylanOS-Crimson-Light para GTK 3 y GTK 4
  cargaron con `Gtk.CssProvider` sin errores usando configuración XDG aislada.
- todos los SVG Plasma/Aurorae Glass pasaron `xmllint --noout`.
- `scripts/check.sh` se ejecutó, pero la QA completa se detuvo en un fallo
  basal no relacionado: Qt 6.4 del host rechaza `const` en
  `apps/calculator/qml/Main.qml:28`. El mismo fallo se reprodujo previamente en
  la rama `development` limpia; las suites anteriores a ese punto pasaron.
- no se ejecutó una sesión KWin real ni una ISO/QEMU con esta rama. Por tanto,
  el blur, la recarga D-Bus y el comportamiento X11/Wayland permanecen como
  validación gráfica pendiente; no se declaran comprobados.

## Componentes para mantenimiento

- motor: `apps/dylanos-configuration/src/services/CrimsonGlassService.*`;
- interfaz: `qml/pages/CrimsonGlassPage.qml` y
  `qml/components/GlassPreview.qml`;
- temas base: `themes/plasma/DylanOS-Crimson-Glass` y
  `themes/aurorae/DylanOS-Crimson-Glass`;
- adaptadores GTK: `themes/gtk/DylanOS-Crimson{,-Light}`;
- generación reproducible: `python3 scripts/lib/generate-theme.py crimson-glass`;
- instalación e inicio de sesión: `scripts/stage.py`.
