// Initial layout only; Plasma invokes this for a new user or an explicit reset.
// The approved DylanOS design uses one top panel; the experimental dock is separate.
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var desktop = allDesktops[i];
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file:///usr/share/wallpapers/DylanOS/DylanOS-Dark.png");
}
var panel = new Panel;
panel.location = "top";
panel.height = 28;
try { panel.floating = true; } catch (e) {}
var launcher = panel.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "distributor-logo-dylanos");
panel.addWidget("org.kde.plasma.appmenu");
panel.addWidget("org.kde.plasma.panelspacer");
var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", ["applications:org.dylanos.welcome.desktop", "applications:org.dylanos.files.desktop", "applications:org.kde.konsole.desktop", "applications:firefox-esr.desktop"]);
panel.addWidget("org.kde.plasma.panelspacer");
panel.addWidget("org.kde.plasma.systemtray");
var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateFormat", "ddd, d MMM");
clock.writeConfig("use24hFormat", 2);
