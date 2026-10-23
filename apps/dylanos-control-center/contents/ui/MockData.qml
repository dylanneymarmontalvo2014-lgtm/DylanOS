pragma Singleton
import QtQuick
import org.kde.plasma.plasma5support as P5Support

/*
 * Accesos secundarios del Centro de Control + ejecutor de comandos.
 * Cada acción abre su módulo real de configuración (kcmshell6); nada es
 * ficticio. El acceso se nombra "KDE Connect" para describir con precisión
 * el servicio que abre; no se presenta como AirDrop.
 */
QtObject {
    readonly property var secondaryActions: [
        { id: "kdeconnect", icon: "kdeconnect", label: "KDE Connect", command: "kcmshell6 kcm_kdeconnect" },
        { id: "project", icon: "video-display", label: "Proyectar", command: "kcmshell6 kcm_kscreen" },
        { id: "powersave", icon: "battery-profile-powersave", label: "Ahorro de energía", command: "kcmshell6 powerdevilprofilesconfig" }
    ]

    function run(command) {
        exec.connectSource(command)
    }

    readonly property P5Support.DataSource exec: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
    }
}
