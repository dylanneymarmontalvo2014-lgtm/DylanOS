.pragma library

/*
 * Catálogo de DylanOS Widgets.
 *
 * Fuente única de verdad para la galería y para los tests de contrato: cada
 * entrada declara tipo de applet, tamaños soportados, categoría, fuente de
 * datos y si necesita red.
 *
 * `status` documenta la viabilidad real de cada widget:
 *   - "ready":       datos reales disponibles en la imagen actual.
 *   - "needs-pkg":   requiere un paquete que todavía no está en el perfil.
 *   - "limited":     funciona, pero con un límite funcional declarado.
 *
 * Ningún widget muestra datos simulados: cuando la fuente no existe, la
 * tarjeta presenta un estado explícito.
 *
 * Es una biblioteca JS (`.pragma library`) y no un singleton QML por el
 * mismo motivo que WidgetTokens.js: los plasmoides se cargan desde el
 * sistema de archivos y los singletons exigirían un qmldir + import path
 * real. Con este patrón el catálogo también se puede ejecutar y verificar
 * con `node`, que es lo que hace scripts/tests/test_widgets.py.
 */

var categories = [
    "Tiempo", "Sistema", "Productividad", "Medios", "Red"
];

var entries = [
    {
        "id": "clock",
        "applet": "com.dylanos.widgets.clock",
        "name": "Reloj",
        "description": "Hora y fecha reales del sistema.",
        "category": "Tiempo",
        "sizes": ["small", "large"],
        "defaultSize": "small",
        "dataSource": "Reloj del sistema",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": true
    },
    {
        "id": "calendar",
        "applet": "com.dylanos.widgets.calendar",
        "name": "Calendario",
        "description": "Mes actual con el día de hoy resaltado.",
        "category": "Tiempo",
        "sizes": ["small", "large", "extra-large"],
        "defaultSize": "small",
        "dataSource": "Fecha del sistema",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": true
    },
    {
        "id": "weather",
        "applet": "com.dylanos.widgets.weather",
        "name": "Clima",
        "description": "Condición actual y pronóstico corto.",
        "category": "Tiempo",
        "sizes": ["small", "medium-wide", "large"],
        "defaultSize": "medium-wide",
        "dataSource": "Proveedor de clima de Plasma",
        "requiresNetwork": true,
        "status": "limited",
        "limit": "Sin proveedor configurado muestra «Configura tu ubicación».",
        "inDefaultLayout": true
    },
    {
        "id": "battery",
        "applet": "com.dylanos.widgets.battery",
        "name": "Batería",
        "description": "Porcentaje y estado de carga.",
        "category": "Sistema",
        "sizes": ["small"],
        "defaultSize": "small",
        "dataSource": "UPower (DBus)",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "resources",
        "applet": "com.dylanos.widgets.resources",
        "name": "CPU y RAM",
        "description": "Uso de CPU y memoria en vivo.",
        "category": "Sistema",
        "sizes": ["small", "medium-wide"],
        "defaultSize": "small",
        "dataSource": "/proc/stat y /proc/meminfo",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "network",
        "applet": "com.dylanos.widgets.network",
        "name": "Red y Wi-Fi",
        "description": "Estado de conexión e interfaz activa.",
        "category": "Red",
        "sizes": ["small"],
        "defaultSize": "small",
        "dataSource": "NetworkManager (DBus)",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "notes",
        "applet": "com.dylanos.widgets.notes",
        "name": "Notas rápidas",
        "description": "Nota de texto editable dentro del widget.",
        "category": "Productividad",
        "sizes": ["small", "medium-wide", "large"],
        "defaultSize": "medium-wide",
        "dataSource": "Configuración del applet",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "media",
        "applet": "com.dylanos.widgets.media",
        "name": "Reproductor",
        "description": "Control de reproducción de la app activa.",
        "category": "Medios",
        "sizes": ["medium-wide"],
        "defaultSize": "medium-wide",
        "dataSource": "MPRIS (playerctl)",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "calculator",
        "applet": "com.dylanos.widgets.calculator",
        "name": "Calculadora",
        "description": "Cálculo rápido con evaluador acotado.",
        "category": "Productividad",
        "sizes": ["small"],
        "defaultSize": "small",
        "dataSource": "Cálculo local",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "shortcuts",
        "applet": "com.dylanos.widgets.shortcuts",
        "name": "Accesos directos",
        "description": "Lanzadores de aplicaciones favoritas.",
        "category": "Productividad",
        "sizes": ["small", "medium-wide"],
        "defaultSize": "small",
        "dataSource": "Aplicaciones .desktop del sistema",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "photos",
        "applet": "com.dylanos.widgets.photos",
        "name": "Fotos",
        "description": "Carrusel de imágenes de una carpeta local.",
        "category": "Medios",
        "sizes": ["medium-wide", "large"],
        "defaultSize": "medium-wide",
        "dataSource": "Carpeta local del usuario",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "screenshot",
        "applet": "com.dylanos.widgets.screenshot",
        "name": "Captura rápida",
        "description": "Botón de captura y últimas capturas.",
        "category": "Sistema",
        "sizes": ["small"],
        "defaultSize": "small",
        "dataSource": "Spectacle y ~/Imágenes",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "clipboard",
        "applet": "com.dylanos.widgets.clipboard",
        "name": "Portapapeles",
        "description": "Contenido actual del portapapeles.",
        "category": "Productividad",
        "sizes": ["small", "medium-wide"],
        "defaultSize": "medium-wide",
        "dataSource": "Portapapeles del sistema",
        "requiresNetwork": false,
        "status": "limited",
        "limit": "Sin historial: muestra el contenido actual (xclip/wl-paste).",
        "inDefaultLayout": false
    },
    {
        "id": "todo",
        "applet": "com.dylanos.widgets.todo",
        "name": "Tareas",
        "description": "Lista de tareas pendientes editable.",
        "category": "Productividad",
        "sizes": ["small", "medium-wide", "large"],
        "defaultSize": "medium-wide",
        "dataSource": "Configuración del applet",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "worldclock",
        "applet": "com.dylanos.widgets.worldclock",
        "name": "Reloj mundial",
        "description": "Varias zonas horarias a la vez.",
        "category": "Tiempo",
        "sizes": ["medium-wide"],
        "defaultSize": "medium-wide",
        "dataSource": "Zonas horarias del sistema",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "pomodoro",
        "applet": "com.dylanos.widgets.pomodoro",
        "name": "Temporizador",
        "description": "Temporizador de enfoque y descanso.",
        "category": "Productividad",
        "sizes": ["small"],
        "defaultSize": "small",
        "dataSource": "Temporizador local",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "disk",
        "applet": "com.dylanos.widgets.disk",
        "name": "Espacio en disco",
        "description": "Uso de almacenamiento por partición.",
        "category": "Sistema",
        "sizes": ["small"],
        "defaultSize": "small",
        "dataSource": "QStorageInfo",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "updates",
        "applet": "com.dylanos.widgets.updates",
        "name": "Actualizaciones",
        "description": "Paquetes APT pendientes y acceso a la tienda.",
        "category": "Sistema",
        "sizes": ["small", "medium-wide"],
        "defaultSize": "small",
        "dataSource": "PackageKit",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "info",
        "applet": "com.dylanos.widgets.info",
        "name": "DylanOS Info",
        "description": "Resumen del sistema y versión instalada.",
        "category": "Sistema",
        "sizes": ["small", "large"],
        "defaultSize": "large",
        "dataSource": "os-release, /proc y kernel",
        "requiresNetwork": false,
        "status": "ready",
        "inDefaultLayout": false
    },
    {
        "id": "next-event",
        "applet": "com.dylanos.widgets.nextevent",
        "name": "Próximo evento",
        "description": "Siguiente evento de un calendario .ics local.",
        "category": "Tiempo",
        "sizes": ["small", "medium-wide"],
        "defaultSize": "medium-wide",
        "dataSource": "Archivo .ics elegido por el usuario",
        "requiresNetwork": false,
        "status": "limited",
        "limit": "Sin calendario de sistema: hay que elegir un .ics.",
        "inDefaultLayout": false
    }
]

var roadmap = [
    { "name": "RSS y noticias", "reason": "Requiere lector de feeds y red." },
    { "name": "Citas", "reason": "Requiere calendario de sistema (Akonadi)." },
    { "name": "Contador de notificaciones", "reason": "Requiere DataSource de notificaciones." }
]

function byCategory(category) {
    return entries.filter(function (entry) {
        return entry.category === category;
    });
}

function search(term) {
    var needle = String(term || "").toLowerCase().trim();
    if (needle.length === 0)
        return entries;
    return entries.filter(function (entry) {
        return entry.name.toLowerCase().indexOf(needle) !== -1
            || entry.description.toLowerCase().indexOf(needle) !== -1
            || entry.category.toLowerCase().indexOf(needle) !== -1;
    });
}

function count() {
    return entries.length;
}
