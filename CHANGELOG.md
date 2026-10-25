- Spotlight: filtrar correctamente las acciones Web/Calcular, conservar la acción web entre muchos resultados y retirar el contador ficticio de archivos.
- Spotlight: importar explícitamente `urllib.parse.quote` para codificar la búsqueda web y evitar una excepción al escribir una consulta.
- Dock: corregir el ancho del applet para que los iconos fijados se muestren; el cálculo previo referenciaba un id QML fuera de su ámbito.
- Centro de Control: quitar asignaciones QML no válidas `Accessible.value` de los sliders de volumen/micrófono que impedían cargar el plasmoid; se conserva el nombre accesible y el propio Slider anuncia su valor.
- SDDM: ajustar el ancho de la tarjeta de acceso al formulario escalado para
  que no quede sobredimensionada en pantallas estrechas.
- Dock predeterminado: integrar el dock propio DylanOS y añadir ampliación
  gradual de los iconos cercanos al cursor; se conservan los lanzadores y la
  papelera.
# Changelog

Todos los cambios relevantes de DylanOS se registran en este archivo. La intención es mantener un histórico claro de la evolución del escritorio, el branding y la plataforma de instalación.

## [Unreleased] - development

### Corregido

- Spotlight: lanzar entradas de aplicaciones `.desktop` con argv y sin `shell=True`; los metacaracteres no se interpretan como código de shell y las comillas malformadas se rechazan. Se añadieron pruebas para argumentos citados, códigos de archivo y separadores de shell.


- Staging: corregir el nombre del archivo de asociaciones MIME del sistema a `mimeapps.list` y terminar las asociaciones con `;`; `mimeapps.info` era ignorado por XDG, por lo que el Explorer no se establecía como aplicación predeterminada a nivel del sistema.

- Instalador: limpiar el contenido previo de la partición raíz ext4 elegida en modo manual antes de extraer `filesystem.squashfs`; evita instalaciones híbridas con archivos obsoletos que `unsquashfs -f` no elimina. La limpieza no sigue enlaces simbólicos.

### Añadido

- Comando `about`, generado por staging y conectado a `MAINTAINERS.txt`.
- Calendario interactivo del Dashboard, silencio de audio en el Centro de Control y guía de uso/capacidades de las aplicaciones.
- Documentación de componentes Workspace, Spotlight, App Center y Calculator; se precisan las limitaciones reales del instalador y las categorías incompletas de Spotlight.
- Control de volumen y silencio del micrófono predeterminado en el Centro de Control mediante `pactl`, con estado no disponible cuando no hay fuente de entrada.
- Dashboard 0.3.0: porcentajes claros y barras Crimson con animación suave y descripciones accesibles para RAM, CPU y filesystem raíz.
- Dashboard 0.3.1: estados de hoy/selección accesibles y transiciones suaves del calendario.
- Dashboard 0.4.0: botón para abrir el Monitor del sistema KDE y ver procesos/métricas detalladas.
- Dashboard 0.4.1: acción «Actualizar» para solicitar métricas al instante y mostrar la hora de consulta.
- Dashboard 0.5.0: gráfica de tendencia de CPU basada en hasta 24 muestras reales de `/proc/stat`.
- Centro de Control DylanOS 0.4.0: modelo de notificaciones compartido y sondeos detenidos cuando el panel está cerrado.
- Centro de Control DylanOS 0.3.0: superficies externas con transparencia moderada y contraste interior conservado.
- Dashboard 0.7.0: temporizador Pomodoro de enfoque/descanso y acabado glass sutil con reflejo superior; superficies del Centro de Control y Notificaciones con transparencia moderada.
- Armonización visual de Configuration, Explorer y Workspace con los tokens Crimson oficiales y estados hover/pressed coherentes.

### Cambiado

- El índice de documentación enlaza las nuevas guías y diferencia las guías activas de los informes históricos.

## [1.0.0-crimson] - 2026-10-18

### Añadido

- Identidad visual DylanOS Crimson consolidada en el repositorio.
- Documentación principal reescrita para reflejar el estado real del proyecto.
- Arquitectura del sistema con shell de trabajo, explorador, tienda y instalador propios.
- Estructura de documentación con índice operativo en `docs/`.

### Cambiado

- Se eliminó la ambigüedad entre la documentación histórica y la documentación activa.
- Se actualizó la referencia a aplicaciones y sectores del sistema para alinearlos con `dylanos-store`, `dylanos-explorer` y `installer/dylanos-installer`.
- Se reforzó la consistencia visual y de marca con los colores oficiales y la referencia Crimson.

### Corregido

- Enlaces y referencias rotos en la documentación principal.
- Descripciones obsoletas que hablaban de soluciones antiguas o de componentes ya no vigentes.

## [0.1.0-alpha] - En desarrollo inicial

### Añadido

- Creación del repositorio oficial.
- Estructura base del proyecto.
- Primeros recursos de documentación.
- Diseño visual de escritorio y flujo de construcción al inicio del proyecto.
