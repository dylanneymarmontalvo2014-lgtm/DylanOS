# DylanOS Dashboard — plasmoid `com.dylanos.dashboard`

Widget Plasma 6 instalado en el escritorio para perfiles nuevos: un muro de
tarjetas de vidrio oscuro como el del preview `escritorio_preview`. Cada tarjeta
trabaja solo con datos reales del sistema o del usuario. Versión de paquete del
applet: 0.8.0.

## Colocación en el escritorio

El layout de perfil nuevo (`themes/lookandfeel/org.dylanos.crimson/contents/layouts/`)
ancla el muro al **borde derecho** del escritorio con `screenGeometry`: 720 px de
ancho, 8 px por debajo de la barra superior y un alto entre 584 y 920 px según la
pantalla. La mitad izquierda queda libre: Plasma coloca el acceso
«Instalar DylanOS» en la primera celda de iconos (superior izquierda) y el muro
no debe taparlo. Si la API de geometría no está disponible, el layout asume
1280×800 en lugar de fallar.

## Tarjetas

- **Reloj**: hora grande del sistema en 12 h con AM/PM en crimson y fecha local;
  se refresca cada 30 segundos.
- **Sistema**: aro Canvas con el porcentaje de CPU y tres barras de RAM, disco
  raíz y uptime desde `/proc/meminfo`, `/proc/uptime`, `/proc/stat` y
  `df -B1 --output=used,size /`. El refresco automático es cada 10 segundos y
  «Actualizar» pide una lectura inmediata con la hora de la consulta.
- **En reproducción**: el reproductor MPRIS activo consultado con `playerctl`
  (estado cada 15 s y posición cada 2 s mientras suena). Muestra título,
  artista, tiempo recorrido/total con barra de posición real (seek con
  `playerctl position`) y controles anterior, reproducir/pausa y siguiente.
  Sin reproductor activo, la tarjeta lo indica y no inventa una pista.
- **Calendario**: mes navegable con ‹ y › y botón «Hoy»; la semana empieza en
  domingo (D L M M J V S). Marca el día actual y la fecha elegida, anuncia
  ambos estados a lectores de pantalla y suaviza hover/selección. No consulta
  Google Calendar ni representa citas.
- **Recordatorios**: lista real del usuario (máximo 100 entradas de 120
  caracteres) con casilla de completado, renombrado inline y borrado. Se guarda
  en `Plasmoid.configuration.recordatorios` (KConfigXT del applet), así que
  sobrevive al reinicio de la sesión. Empieza vacía; nada se inventa.
- **Enfoque**: temporizador Pomodoro 25/5 con Iniciar, Pausar/Continuar,
  Reiniciar, progreso animado y contador de ciclos. El cambio de bloque es
  manual y el contador no persiste al cerrar el widget.

## Tendencia de CPU

La tarjeta Sistema conserva la gráfica Crimson Canvas con hasta 24 lecturas
válidas reales de CPU (deltas de `/proc/stat`, contadores guest descontados).
No fabrica puntos para completar el gráfico; con menos de dos muestras no hay
trazo y el texto accesible comunica el número de muestras y el último
porcentaje.

## Monitor completo

«Abrir Monitor del sistema» ejecuta `plasma-systemmonitor`, instalado desde el
perfil base de DylanOS. Si el comando no está disponible en una instalación
personalizada, no se inicia una aplicación externa de reemplazo.

## Acabado visual tipo glass

Todas las tarjetas usan fondo oscuro semitransparente (`#D9101014`), borde
blanco delicado con reflejo superior tenue y acento crimson `#DC143C`; la
tarjeta de Enfoque se destaca con borde carmesí mientras corre. El contraste
se mantiene legible. El desenfoque real del fondo depende del compositor KWin
(`BlurBehindEffect`); el widget no simula blur ni lo promete en equipos sin
composición.

## Limitaciones y QA

El widget no incorpora tarjeta de clima (exigiría consultas remotas, contra la
regla de «sin simulaciones») ni una segunda bandeja de controles rápidos
(duplicaría el [Centro de Control](../dylanos-control-center/README.md)). Las
pruebas `test_pomodoro.py`, `test_shell_contract.py` y `test_staging.py`
comprueban cálculos puros, contrato de QML y empaquetado; el layout simulado se
prueba con Node en `test_desktop.py`. Ninguna de ellas demuestra el render
visual. Para QA gráfico hace falta cargar el plasmoid (y qmllint en el `main.qml`
usa la ruta Qt del chroot; `org.kde.plasma.plasmoid` vive compilado dentro de
`libPlasmaQuick`, así que los avisos de id externo del lint standalone son
inofensivos).

Consulta la [guía general](../../docs/guia-de-uso.md) y el
[documento de shell](../../docs/dylanos-shell.md).
