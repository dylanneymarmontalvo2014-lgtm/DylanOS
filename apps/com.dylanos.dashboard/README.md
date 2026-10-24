# DylanOS Dashboard — plasmoid `com.dylanos.dashboard`

Widget Plasma 6 instalado en el escritorio para perfiles nuevos. Combina hora/fecha, calendario local y lecturas del sistema local. Versión de paquete del applet: 0.7.0.

## Calendario

- Cambia de mes con ‹ y ›.
- Pulsa una fecha para seleccionarla; el panel marca el día elegido y resalta hoy. «Hoy» regresa a la fecha actual.
- Muestra la fecha seleccionada como dato de calendario; el día actual se distingue del elegido y el lector de pantalla anuncia «hoy» y «seleccionado» cuando corresponde. Los estados hover/selección tienen transiciones breves. **No** consulta Google Calendar ni representa citas/recordatorios.

## Actualización de métricas

El panel refresca las métricas cada 10 segundos. «Actualizar» solicita una lectura inmediatamente y la etiqueta «Consulta» muestra la hora local de la última solicitud; al inicio indica que está esperando la primera lectura. Las solicitudes leen memoria, uptime, CPU y el filesystem raíz desde las fuentes locales habituales.

## Monitor completo

El botón «Abrir Monitor del sistema» ejecuta `plasma-systemmonitor`, instalado desde el perfil base de DylanOS. Abre el monitor de KDE para consultar procesos y métricas más detalladas; si el comando no está disponible en una instalación personalizada, no se inicia una aplicación externa de reemplazo.

## Tendencia de CPU

La gráfica reúne hasta 24 lecturas válidas reales de CPU tomadas de `/proc/stat`. Se amplía con cada lectura; no fabrica puntos para completar el gráfico. Cada lectura automática ocurre aproximadamente cada 10 segundos (ventana aproximada de cuatro minutos, salvo actualizaciones manuales). Al inicio muestra que espera datos; el texto accesible comunica el número de muestras y el último porcentaje.

## Métricas

Las barras muestran el porcentaje y la capacidad usada de RAM y del filesystem raíz, además del porcentaje de CPU. Los indicadores Crimson transicionan suavemente entre muestras y exponen una descripción accesible con el valor porcentual; los valores se limitan al intervalo 0–100% para proteger la visualización de lecturas anómalas.

Lee `/proc/meminfo`, `/proc/uptime`, `/proc/stat` y `df -B1 --output=used,size /`. El muestreo de sistema ocurre cada 10 segundos. CPU usa la diferencia entre dos muestras, por lo que al primer render dice «leyendo…». Se evitan contadores guest duplicados. El disco mostrado corresponde al filesystem raíz `/`; no es un escaneo de todas las particiones. Si la fuente falta, la interfaz indica que no hay datos en vez de inventarlos.

## Limitaciones y QA

El widget no dibuja eventos de calendario, pronóstico ni agenda. La selección de fecha es solo UI, no crea ni guarda eventos. Las pruebas `test_shell_contract.py` y `test_staging.py` comprueban el contrato y empaquetado; no demuestran el render visual del QML. Para QA gráfico hace falta cargar el plasmoid en una sesión Plasma 6.

Consulta [Centro de Control](../dylanos-control-center/README.md), [guía general](../../docs/guia-de-uso.md) y [documento de shell](../../docs/dylanos-shell.md).

## Temporizador de enfoque

Incluye un temporizador local tipo Pomodoro: 25 minutos de enfoque y 5 minutos de
descanso. «Iniciar» comienza el bloque, «Pausar» conserva el tiempo restante,
«Continuar» retoma el conteo y «Reiniciar» devuelve el bloque actual a su
duración completa. Al terminar, el widget marca la sesión y propone comenzar
el descanso (o volver al enfoque); el siguiente bloque requiere pulsar el
botón, así que no cambia de modo a escondidas. La hora límite se calcula con
la hora del sistema (`Date.now()`), el panel muestra progreso
animado y el contador de sesiones vive solo mientras el widget está cargado;
no se guarda historial ni se envían notificaciones.

`contents/ui/PomodoroClock.js` contiene cálculos puros de duración, modo,
tiempo restante y progreso. `scripts/tests/test_pomodoro.py` los prueba con Node
cuando está disponible; el contrato de QML también se comprueba en las pruebas
de shell y staging. El render final requiere QA en una sesión Plasma 6.


## Acabado visual tipo glass

Dashboard 0.7.0 usa una superficie semitransparente oscura, borde blanco
delicado y un reflejo superior tenue; la tarjeta Pomodoro también deja pasar
un poco de fondo. Se mantiene la opacidad suficiente para leer texto y métricas.
El desenfoque real del fondo depende del compositor/KWin y del soporte
`BlurBehindEffect` de Plasma; el widget no simula blur ni promete que exista en
todos los equipos.
