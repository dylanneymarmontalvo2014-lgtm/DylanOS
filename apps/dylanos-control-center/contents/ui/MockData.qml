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
    // kcmshell6 puede no estar disponible en el sistema; sin el flag el
    // ejecutor emite comandos que nadie consumirá.
    property bool kcmshellAvailable: true
    property var gamingStatus: ({})
    property var iotStatus: ({})
    readonly property var gamingProfileIds: ["balanced", "performance", "competitive", "streaming", "emulation"]

    function refreshGaming() {
        exec.connectSource("dylanos-configuration --gaming-status --headless")
    }
    function refreshIoT() {
        exec.connectSource("dylanos-configuration --iot-status --headless")
    }
    function openIoTSettings() {
        run("dylanos-configuration --page iot")
    }
    function setGamingProfile(id) {
        if (gamingProfileIds.indexOf(id) < 0) return
        exec.connectSource("dylanos-configuration --gaming-profile " + id + " --headless")
    }
    function restoreGamingProfile() {
        exec.connectSource("dylanos-configuration --restore-gaming-profile --headless")
    }
    function openGamingSettings() {
        run("dylanos-configuration --page gaming")
    }

    readonly property var secondaryActions: [
        { id: "kdeconnect", icon: "kdeconnect", label: "KDE Connect", command: "kcmshell6 kcm_kdeconnect" },
        { id: "project", icon: "video-display", label: "Proyectar", command: "kcmshell6 kcm_kscreen" },
        { id: "powersave", icon: "battery-profile-powersave", label: "Ahorro de energía", command: "kcmshell6 kcm_powerdevilprofilesconfig" }
    ]

    function run(command) {
        if (!kcmshellAvailable) return
        exec.connectSource(command)
    }

    readonly property P5Support.DataSource exec: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            if (sourceName === "dylanos-configuration --gaming-status --headless") {
                try {
                    MockData.gamingStatus = JSON.parse(data.stdout || "{}")
                } catch (error) {
                    MockData.gamingStatus = ({})
                }
            } else if (sourceName === "dylanos-configuration --iot-status --headless") {
                try {
                    MockData.iotStatus = JSON.parse(data.stdout || "{}")
                } catch (error) {
                    MockData.iotStatus = ({})
                }
            }
        }
    }
}
