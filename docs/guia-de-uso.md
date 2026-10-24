# Guía de uso y estado de las funciones de DylanOS

Esta guía es el mapa práctico de la rama `development`. Describe lo que el código actual expone, cómo abrirlo y las limitaciones visibles que conviene conocer. Las capturas de `previews/` son referencias visuales, no pruebas de que cada detalle esté implementado. Para compilación, instalación de la ISO y pruebas, sigue [Instalación y QA](install.md); para diseño interno, [Arquitectura](architecture.md).

## Escritorio y widgets

El perfil de Plasma se aplica a perfiles nuevos mediante el layout de `themes/lookandfeel/org.dylanos.crimson/contents/layouts/`. No reemplaza paneles ni widgets de un perfil de usuario que ya existe. La configuración se genera por look-and-feel al crear el perfil y no ofrece un gestor DylanOS para editar/persistir widgets en masa.

- **Dashboard DylanOS** (`com.dylanos.dashboard`, versión 0.4.1): reloj, calendario mensual interactivo, selección de día y botón «Hoy»; muestra RAM, CPU, uso del filesystem raíz y uptime desde fuentes locales. Los medidores indican porcentaje y capacidad, con transiciones suaves y etiquetas accesibles. El calendario diferencia hoy de la fecha elegida, anuncia ambos estados a lectores de pantalla y suaviza los cambios visuales al pasar el cursor o seleccionar. El botón «Actualizar» solicita nuevas métricas al momento y muestra la hora de la consulta; el refresco automático sigue cada 10 segundos. «Abrir Monitor del sistema» lanza `plasma-systemmonitor` para ver procesos y estadísticas detalladas. No crea citas, tareas ni datos de clima.
- **Centro de Control DylanOS** (`com.dylanos.controlcenter`, versión 0.2.0): notificaciones reales de Plasma, Wi-Fi y Bluetooth cuando sus servicios están disponibles, No molestar mediante NotificationManager, controles de brillo, volumen de salida y volumen/silencio del micrófono predeterminado, además de reproducción MPRIS si hay un reproductor compatible. Los controles de audio usan `pactl`; micrófono y salida requieren fuentes presentes mediante PulseAudio o PipeWire Pulse. El selector oscuro/claro aplica los esquemas `DylanOSDark` y `DylanOSLight`. Las consultas están escalonadas (audio/brillo cada 5 s; Wi-Fi, tema y reproducción cada 15 s). No todos los equipos ofrecen brillo, audio, Bluetooth o reproductor.
- **Barra superior**: lanzador, nombre de la aplicación activa, menú de aplicación, bandeja, búsqueda, Centro de Control y reloj.
- **Dock inferior**: tareas de Plasma, accesos fijados y papelera; el plasmoid `com.dylanos.dock` es alternativo, no el dock predeterminado.
- **Búsqueda**: abre Spotlight con `Ctrl+Espacio` o con el icono de lupa. Escape la cierra.

El orden exacto y los tipos de panel se definen en el [layout del escritorio](../themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js). La primera instalación de los widgets no comprueba por sí sola que el contenido se haya renderizado en una sesión gráfica; la captura/QA visual requiere Plasma real o VM.

## Aplicaciones y comandos

| Aplicación o comando | Uso | Cómo abrir |
|---|---|---|
| DylanOS Workspace (`dylanos`) | Bienvenida, archivos básicos, notas locales, desarrollo, monitor y ajustes | Menú o `dylanos --page welcome`; páginas: `welcome`, `files`, `notes`, `dev`, `monitor`, `settings` |
| DylanOS Explorer (`dylanos-explorer`) | Gestor de archivos del sistema basado en KIO | Menú «Archivos» o `dylanos-explorer [ruta]`; ver su [guía](../apps/dylanos-explorer/README.md) |
| DylanOS Store (`dylanos-store`) | Catálogo/gestión de software mediante libdiscover y los backends configurados | Menú o `dylanos-store`; Workspace abre actualizaciones con `dylanos-store --mode Update` |
| DylanOS App Center (`dylanos-app-center`) | Explorar y lanzar aplicaciones XDG instaladas | Menú; ver `apps/dylanos-app-center/` |
| DylanOS Calculator (`dylanos-calculator`) | Calculadora de escritorio | Menú o comando `dylanos-calculator` |
| DylanOS Configuration (`dylanos-configuration`) | Preferencias DylanOS y módulos nativos de KDE | Menú o `dylanos-configuration`; secciones mediante `--page` |
| DylanOS Spotlight (`dylanos-spotlight`) | Lanzador/búsqueda rápida | `Ctrl+Espacio`, lupa o `dylanos-spotlight` |
| DylanOS Console (`dylanos-console`) | Terminal Kitty con configuración Crimson | Menú o `dylanos-console [--directory ruta]` |
| `about` | Agradece a las personas listadas como mantenedoras | Terminal: `about` |
| `neofetch` / `sistema` | Resumen del equipo con logo gráfico; `sistema` es alias Bash | Terminal interactiva |
| `dylanos-installer` | Asistente para instalar DylanOS | Acceso «Instalar DylanOS» en la sesión live o menú |

`dylanos` acepta `--page` con las seis claves indicadas arriba. También ofrece opciones de QA `--smoke`, `--screenshot archivo` y `--appearance dark|light`; estas opciones no son necesarias para el uso cotidiano. `dylanos-configuration --page <sección>` abre una sección del panel (por ejemplo, `network`, `sound`, `display`, `power`, `accounts` o `personalization`).

El comando `about` lee `/usr/share/dylanos/MAINTAINERS.txt` y usa los bloques `MANTENEDOR`; no mantiene una lista duplicada dentro del script. Si el archivo no está disponible o no contiene nombres válidos, muestra un error en lugar de inventar créditos.

### Workspace

- **Bienvenida**: accesos a tareas, ajustes y actualización.
- **Archivos**: navegación local, filtro por nombre en la carpeta actual, favoritos XDG, archivos ocultos, apertura con la app predeterminada, crear carpetas, copiar/pegar, renombrar sin reemplazar y papelera. La aplicación dedicada para gestión completa es DylanOS Explorer.
- **Notas**: notas de texto persistidas localmente en SQLite bajo los datos del usuario; no se sincronizan con la nube.
- **Desarrollo**: detecta un conjunto acotado de herramientas instaladas y crea plantillas locales Python, Web o C++. Al crear, no descarga dependencias. Permite abrir el proyecto en VS Code, Console o Explorer.
- **Monitor**: CPU, memoria, disco, uptime y procesos; actualiza aproximadamente cada 2,5 segundos y se puede pausar. El monitor avanzado abre Plasma System Monitor.
- **Ajustes**: cambia tema del usuario y abre Configuration/KCM para ajustes de red, Bluetooth, sonido, pantallas, energía, teclado, cuentas y escritorio.

### Spotlight: alcance actual

La ventana busca aplicaciones leyendo entradas `.desktop` y proyectos en `~/Proyectos`, `~/Projects`, `~/DylanOS` y `~/workspace`. La consulta pretende ofrecer una búsqueda web en DuckDuckGo, pero hay un error de importación de `urllib.parse` en el código actual que puede interrumpir esa ruta; no asumir que funciona hasta corregirlo. La activación de aplicaciones usa su línea `Exec` de escritorio; las carpetas se abren con DylanOS Explorer cuando está instalado.

**Filtros que todavía no están completos:** aunque la interfaz muestra «Archivos» y «Calcular», el backend actual no indexa archivos recientes ni implementa un modo de filtro de archivos/cálculo de extremo a extremo. La aritmética puede aparecer como resultado cuando se escribe una expresión en la consulta; no interpretar la etiqueta como garantía de un motor de cálculo completo. El contador visual de archivos es fijo/estimado, no un inventario real. La ruta que construye el enlace web también referencia `urllib.parse.quote` sin importar el módulo `urllib`, de modo que puede fallar al escribir una consulta. Estas funciones no se deben anunciar como búsqueda de archivos o web plenamente implementada hasta corregir y probar el backend.

## Instalador: precauciones y alcance

La aplicación nativa Qt WebEngine inicia un backend REST local en `127.0.0.1:8088`. Cuando se ejecuta con root y detecta un disco objetivo, el endpoint de instalación puede particionar, formatear, extraer el sistema, crear el usuario y configurar GRUB. **La instalación automática sobre un disco real es destructiva:** revisa el dispositivo y las opciones antes de continuar; para QA usa una VM y un disco virtual desechable.

Sin privilegios root o sin un dispositivo de destino presente, el backend trabaja en modo de vista previa y no escribe el disco. La interfaz puede usar catálogos de respaldo si el backend no responde; por eso los datos de respaldo no prueban detección real de hardware.

**Limitación del modo manual:** el backend busca una partición ext4 existente y una ESP opcional. Los botones visuales «Nueva partición», «Editar», «Eliminar» y «Revertir» del prototipo no están conectados a operaciones reales de particionado. No los uses como si aplicaran cambios. El camino automático crea GPT, una ESP, una partición BIOS boot y una raíz ext4; confirma que el disco elegido sea el de la VM o equipo destinado a DylanOS.

El frontend aún contiene simulación/valores de respaldo históricos. La instalación real requiere backend conectado, privilegios y disco válido; si el backend no responde, el frontend puede iniciar una barra simulada de progreso que **no instala el sistema**. No declares una instalación completada basándote en esa animación. La [guía del instalador](../installer/dylanos-installer/docs/README.md) describe API y ejecución; la validación real requiere probar la ruta del backend en VM.

## Perfiles de paquetes

- `packages/default/packages.list`: base de escritorio y aplicaciones habituales; incluye `playerctl` para controles MPRIS.
- `packages/development/packages.list`: herramientas adicionales de desarrollo, incluido Visual Studio Code desde el repositorio de Microsoft, además de Git, toolchain, Node.js, Python y utilidades.
- `packages/build/packages.list`: dependencias de construcción; el build puede purgar dependencias de desarrollo que no necesita la ISO final.

El perfil de paquetes determina qué comandos habrá en la imagen; la presencia de un botón o acceso no instala por sí sola dependencias opcionales. Consulta [Optimización](optimization.md) y los archivos de lista para el detalle vigente.

## Enlaces relacionados

- [Instalación, build y QA](install.md)
- [Arquitectura](architecture.md)
- [DylanOS Shell, widgets y consola](dylanos-shell.md)
- [Mantenedores](../MAINTAINERS.txt)
- [Código del instalador](../installer/dylanos-installer/docs/README.md)
