pragma Singleton
import QtQuick
import org.kde.plasma.plasma5support as P5Support

/*
 * Accesos secundarios del Centro de Control + ejecutor de comandos.
 * Cada acción abre su módulo real de configuración (kcmshell6); nada es
 * ficticio. "AirDrop" se implementa vía KDE Connect, el equivalente real
 * disponible en la base KDE de DylanOS.
 */
QtObject {
    readonly property var secondaryActions: [
        { id: "kdeconnect", icon: "kdeconnect", label: "AirDrop", command: "kcmshell6 kcm_kdeconnect" },
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
