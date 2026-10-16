// Initial layout for new profiles. Never remove an existing user's panels.
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var desktop = allDesktops[i];
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file:///usr/share/wallpapers/DylanOS/dylanos-default.png");
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

var clock = menuBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd, d MMM");
clock.writeConfig("use24hFormat", 2);

// Plasma floating bottom dock with intelligent auto-hide (dodgewindows).
var dock = new Panel;
dock.location = "bottom";
dock.height = 72;
dock.alignment = "center";
dock.lengthMode = "fit";
dock.floating = true;
dock.opacity = "translucent";
dock.hiding = "dodgewindows";

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
// Apps fijadas en el dock inferior, en este orden: explorador de archivos,
// Firefox, VSCodium, App Center, Ajustes de DylanOS y Calculadora.
// Gestor de archivos: DylanOS Explorer nativo (dolphin sigue instalado como
// vía de reversión, pero no fijado).
tasks.writeConfig("launchers", [
    "applications:org.dylanos.explorer.desktop",
    "applications:firefox-esr.desktop",
    "applications:codium.desktop",
    "applications:dylanos-app-center.desktop",
    "applications:org.dylanos.store.desktop",
    "applications:org.dylanos.settings.desktop",
    "applications:org.dylanos.calculator.desktop"
]);
tasks.writeConfig("showOnlyCurrentScreen", true);
tasks.writeConfig("showOnlyCurrentDesktop", false);
tasks.writeConfig("maxStripes", 1);
