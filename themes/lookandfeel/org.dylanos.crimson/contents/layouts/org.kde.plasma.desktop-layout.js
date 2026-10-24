// Initial layout for new profiles. Never remove an existing user's panels.
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var desktop = allDesktops[i];
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file:///usr/share/wallpapers/DylanOS/dylanos-default.png");
}

// Dashboard inicial sobre el escritorio: calendario interactivo, reloj y
// datos de memoria/tiempo activo leídos del sistema local. Se añade solo al
// layout de perfiles nuevos, sin tocar los paneles ni cambiar el wallpaper.
for (var i = 0; i < allDesktops.length; i++) {
    allDesktops[i].addWidget("com.dylanos.dashboard", 48, 96, 500, 470);
}

// Barra superior tipo barra de menú (estilo macOS Tahoe): logotipo, nombre de
// la aplicación activa y sus menús de acciones (Archivo, Editar, Ver, ...) a
// la izquierda; el área de estado y el reloj pegados al borde derecho.
//
// No es flotante y no se oculta: una barra de menú debe mostrar sus elementos
// completos y siempre disponibles. Un panel flotante reserva margen perimetral
// para sus esquinas, y con 32 px de alto ese margen recortaba el área de estado
// y el reloj (por eso el alto se calcula sobre la unidad de la retícula).
var panelUnit = (typeof gridUnit === "number" && gridUnit > 0) ? gridUnit : 18;
var menuBar = new Panel;
menuBar.location = "top";
menuBar.height = Math.round(panelUnit * 2);
menuBar.floating = false;
menuBar.opacity = "translucent";
// Con "letwindowscover" las ventanas maximizadas no la cubren (sigue
// reservando su franja), pero una app a pantalla completa SÍ la cubre:
// la barra superior se oculta sola en juegos, vídeo y fullscreen.
menuBar.hiding = "letwindowscover";

var launcher = menuBar.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "distributor-logo-dylanos");

// Nombre de la aplicación activa, en negrita.
menuBar.addWidget("com.dylanos.activeapp");

// Los menús de acciones de la aplicación van pegados a su nombre: el separador
// elástico se coloca DESPUÉS de ellos, de modo que el nombre y sus menús nunca
// se separan ni se cruzan, y todo el espacio libre queda entre el menú y el
// área de estado.
menuBar.addWidget("org.kde.plasma.appmenu");

menuBar.addWidget("org.kde.plasma.panelspacer");

// DylanOS NO incluye el cambiador de escritorios (org.kde.plasma.pager) en la
// barra superior: ese elemento nunca debe aparecer. Los escritorios virtuales
// se gestionan con los atajos de KWin y el gestor de tareas del dock inferior.

menuBar.addWidget("org.kde.plasma.systemtray");

// Búsqueda (lupa) que lanza DylanOS Spotlight, como en el preview.
menuBar.addWidget("com.dylanos.search");

// Centro de Control de DylanOS: campana con badge que despliega las
// notificaciones y los controles rápidos del preview (Wi-Fi, Bluetooth,
// No molestar, Modo oscuro, brillo, volumen, reproductor).
menuBar.addWidget("com.dylanos.controlcenter");

var clock = menuBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd dd 'de' MMM");
// 12 horas con AM/PM, como en el preview ("9:09 AM").
clock.writeConfig("use24hFormat", 1);

// Plasma floating bottom dock with intelligent auto-hide (dodgewindows).
var dock = new Panel;
dock.location = "bottom";
dock.height = 82;
dock.alignment = "center";
dock.lengthMode = "fit";
dock.floating = true;
dock.opacity = "translucent";
dock.hiding = "dodgewindows";

// Dock propio de DylanOS: ampliación suave al pasar el cursor, con los
// iconos vecinos creciendo de forma gradual. La papelera sigue disponible.
dock.addWidget("com.dylanos.dock");
dock.addWidget("org.kde.plasma.trash");
