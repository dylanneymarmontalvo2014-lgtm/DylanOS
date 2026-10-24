# DylanOS Dashboard — plasmoid `com.dylanos.dashboard`

Widget Plasma 6 instalado en el escritorio para perfiles nuevos. Combina hora/fecha, calendario local y lecturas del sistema local. Versión de paquete del applet: 0.3.0.

## Calendario

- Cambia de mes con ‹ y ›.
- Pulsa una fecha para seleccionarla; el panel marca el día elegido y resalta hoy. «Hoy» regresa a la fecha actual.
- Muestra la fecha seleccionada como dato de calendario; **no** consulta Google Calendar ni representa citas/recordatorios.

## Métricas

Las barras muestran el porcentaje y la capacidad usada de RAM y del filesystem raíz, además del porcentaje de CPU. Los indicadores Crimson transicionan suavemente entre muestras y exponen una descripción accesible con el valor porcentual; los valores se limitan al intervalo 0–100% para proteger la visualización de lecturas anómalas.

Lee `/proc/meminfo`, `/proc/uptime`, `/proc/stat` y `df -B1 --output=used,size /`. El muestreo de sistema ocurre cada 10 segundos. CPU usa la diferencia entre dos muestras, por lo que al primer render dice «leyendo…». Se evitan contadores guest duplicados. El disco mostrado corresponde al filesystem raíz `/`; no es un escaneo de todas las particiones. Si la fuente falta, la interfaz indica que no hay datos en vez de inventarlos.

## Limitaciones y QA

El widget no dibuja eventos de calendario, pronóstico ni agenda. La selección de fecha es solo UI, no crea ni guarda eventos. Las pruebas `test_shell_contract.py` y `test_staging.py` comprueban el contrato y empaquetado; no demuestran el render visual del QML. Para QA gráfico hace falta cargar el plasmoid en una sesión Plasma 6.

Consulta [Centro de Control](../dylanos-control-center/README.md), [guía general](../../docs/guia-de-uso.md) y [documento de shell](../../docs/dylanos-shell.md).