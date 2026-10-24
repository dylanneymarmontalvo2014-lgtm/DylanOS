pragma Singleton
import QtQuick
import org.kde.plasma.plasma5support as P5Support
import org.kde.bluezqt as BluezQt
import org.kde.notificationmanager as NotificationManager

/*
 * SystemStatus — Bloque 3 completo (funcional, NO VERIFICADO en hardware real)
 *
 * Todo aquí se conecta al sistema real a través de:
 *   - BluezQt (API pública estable) para Bluetooth
 *   - nmcli / qdbus6 / pactl / plasma-apply-colorscheme / playerctl,
 *     ejecutados vía el motor "executable" de Plasma5Support
 *
 * Requisitos en el sistema (deberían venir con Plasma 6 + NetworkManager,
 * salvo playerctl que hay que instalar aparte):
 *   sudo apt install network-manager qdbus6 playerctl pipewire-pulse
 *
 * "No molestar" usa la API pública NotificationManager.Settings de Plasma;
 * su estado y cambios se comparten con el sistema y otras aplicaciones.
 */
QtObject {
    id: root

    // DND global de Plasma: el plazo y las inhibiciones de aplicaciones son
    // observados directamente; no se representa un estado local ficticio.
    property NotificationManager.Settings notificationSettings: NotificationManager.Settings {}
    readonly property bool doNotDisturb: notificationSettings.notificationsInhibitedByApplication ||
        (notificationSettings.notificationsInhibitedUntil && notificationSettings.notificationsInhibitedUntil > new Date())
    readonly property bool dndLockedByApplication: notificationSettings.notificationsInhibitedByApplication
    function toggleDoNotDisturb() {
        if (dndLockedByApplication) return
        if (doNotDisturb) notificationSettings.resetNotificationsInhibitedUntil()
        else notificationSettings.setNotificationsInhibitedUntil(new Date(Date.now() + 8 * 60 * 60 * 1000))
    }

    // =====================================================================
    // BLUETOOTH (BluezQt — API pública)
    // =====================================================================
    readonly property var adapter: BluezQt.Manager.usableAdapter
    readonly property bool bluetoothAvailable: adapter !== null
    readonly property bool bluetoothPowered: bluetoothAvailable && adapter.powered

    function toggleBluetooth() {
        if (!bluetoothAvailable) return
        adapter.powered = !adapter.powered
    }

    // =====================================================================
    // WI-FI (nmcli)
    // =====================================================================
    property bool wifiAvailable: false
    property bool wifiPowered: false
    property string wifiSsid: ""

    function toggleWifi() {
        if (!wifiAvailable) return
        exec.connectSource(wifiPowered ? "nmcli radio wifi off" : "nmcli radio wifi on")
    }

    // =====================================================================
    // BRILLO (D-Bus PowerDevil)
    // =====================================================================
    property bool brightnessAvailable: false
    property int brightnessMax: 100
    property int brightnessRaw: 0
    readonly property real brightnessValue: brightnessMax > 0 ? brightnessRaw / brightnessMax : 0

    function setBrightness(normalizedValue) {
        const target = Math.round(normalizedValue * brightnessMax)
        brightnessRaw = target // respuesta inmediata en UI
        exec.connectSource(
            "qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightnessSilent " + target
        )
    }

    // =====================================================================
    // VOLUMEN (pactl)
    // =====================================================================
    property bool volumeAvailable: false
    property real volumeValue: 0
    property bool volumeMuted: false

    function setVolume(normalizedValue) {
        const pct = Math.round(normalizedValue * 100)
        volumeValue = normalizedValue
        exec.connectSource("pactl set-sink-volume @DEFAULT_SINK@ " + pct + "%")
    }

    function toggleMute() {
        if (volumeAvailable) exec.connectSource("pactl set-sink-mute @DEFAULT_SINK@ toggle")
    }

    // Entrada de audio: consulta y modifica la fuente predeterminada de PulseAudio/PipeWire.
    property bool microphoneAvailable: false
    property real microphoneVolumeValue: 0
    property bool microphoneMuted: false

    function setMicrophoneVolume(normalizedValue) {
        const pct = Math.round(normalizedValue * 100)
        microphoneVolumeValue = normalizedValue
        exec.connectSource("pactl set-source-volume @DEFAULT_SOURCE@ " + pct + "%")
    }

    function toggleMicrophoneMute() {
        if (microphoneAvailable) exec.connectSource("pactl set-source-mute @DEFAULT_SOURCE@ toggle")
    }

    // =====================================================================
    // MODO OSCURO (plasma-apply-colorscheme)
    // =====================================================================
    property bool darkModeActive: true

    function toggleDarkMode() {
        const target = !darkModeActive
        darkModeActive = target // respuesta inmediata en UI
        exec.connectSource("plasma-apply-colorscheme " + (target ? "DylanOSDark" : "DylanOSLight"))
    }

    // =====================================================================
    // REPRODUCTOR MPRIS (playerctl)
    // =====================================================================
    property bool mprisAvailable: false
    property bool mprisPlaying: false
    property string mprisTitle: ""
    property string mprisArtist: ""

    function mprisPlayPause() { exec.connectSource("playerctl play-pause") }
    function mprisNext() { exec.connectSource("playerctl next") }
    function mprisPrevious() { exec.connectSource("playerctl previous") }

    // Polling solo mientras el desplegable está abierto; los cambios de
    // audio/red/tema son de lectura bajo demanda, no servicios residentes.
    property bool monitoringActive: false

    function setMonitoringActive(active) {
        if (monitoringActive === active) return
        monitoringActive = active
        if (active) {
            refreshAudioAndBrightness()
            refreshMediaAndAppearance()
            exec.connectSource("nmcli radio wifi")
        }
    }

    // =====================================================================
    // MOTOR DE EJECUCIÓN COMPARTIDO
    // =====================================================================
    property P5Support.DataSource exec: P5Support.DataSource {
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            const out = (data["stdout"] || "").trim()
            const err = (data["stderr"] || "").trim()

            // ---- Wi-Fi ----
            if (sourceName === "nmcli radio wifi") {
                root.wifiAvailable = (out === "enabled" || out === "disabled")
                root.wifiPowered = (out === "enabled")
                if (root.wifiPowered) exec.connectSource("nmcli -t -f active,ssid dev wifi")
                else root.wifiSsid = ""
            } else if (sourceName.indexOf("nmcli -t -f active,ssid") === 0) {
                let ssid = ""
                const lines = out.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("yes:") === 0) { ssid = lines[i].substring(4); break }
                }
                root.wifiSsid = ssid
            } else if (sourceName.indexOf("nmcli radio wifi ") === 0) {
                exec.connectSource("nmcli radio wifi")

            // ---- Brillo ----
            } else if (sourceName.indexOf("brightnessMax") !== -1) {
                const n = parseInt(out)
                if (!isNaN(n) && n > 0) { root.brightnessMax = n; root.brightnessAvailable = true }
                else { root.brightnessAvailable = false }
            } else if (sourceName.indexOf(".brightness ") !== -1 || sourceName.slice(-11) === ".brightness") {
                const n = parseInt(out)
                if (!isNaN(n)) root.brightnessRaw = n

            // ---- Volumen ----
            } else if (sourceName === "pactl get-sink-volume @DEFAULT_SINK@") {
                const match = out.match(/(\d+)%/)
                if (match) { root.volumeValue = parseInt(match[1]) / 100; root.volumeAvailable = true }
                else { root.volumeAvailable = false }
            } else if (sourceName === "pactl get-sink-mute @DEFAULT_SINK@") {
                root.volumeMuted = out.indexOf("yes") !== -1
            } else if (sourceName === "pactl get-source-volume @DEFAULT_SOURCE@") {
                const match = out.match(/(\d+)%/)
                if (match && err === "") {
                    root.microphoneVolumeValue = parseInt(match[1]) / 100
                    root.microphoneAvailable = true
                } else {
                    root.microphoneAvailable = false
                }
            } else if (sourceName === "pactl get-source-mute @DEFAULT_SOURCE@") {
                root.microphoneMuted = out.indexOf("yes") !== -1

            // ---- Modo oscuro ----
            } else if (sourceName.indexOf("kreadconfig6") === 0) {
                root.darkModeActive = out.trim() === "DylanOSDark"

            // ---- MPRIS ----
            } else if (sourceName === "playerctl status") {
                root.mprisAvailable = (err === "" && out !== "")
                root.mprisPlaying = (out === "Playing")
                if (root.mprisAvailable) exec.connectSource("playerctl metadata --format {{title}}|||{{artist}}")
            } else if (sourceName.indexOf("playerctl metadata") === 0) {
                const parts = out.split("|||")
                root.mprisTitle = parts[0] || "Sin reproducción"
                root.mprisArtist = parts[1] || ""
            }
        }
    }

    // =====================================================================
    // Polling escalonado: audio/brillo cada 5 s; apariencia, media y Wi-Fi cada 15 s.
    // =====================================================================
    function refreshAudioAndBrightness() {
        exec.connectSource("qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightnessMax")
        exec.connectSource("qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightness")
        exec.connectSource("pactl get-sink-volume @DEFAULT_SINK@")
        exec.connectSource("pactl get-sink-mute @DEFAULT_SINK@")
        exec.connectSource("pactl get-source-volume @DEFAULT_SOURCE@")
        exec.connectSource("pactl get-source-mute @DEFAULT_SOURCE@")
    }

    function refreshMediaAndAppearance() {
        exec.connectSource("kreadconfig6 --file kdeglobals --group General --key ColorScheme")
        exec.connectSource("playerctl status")
    }

    property Timer fastPoll: Timer {
        interval: 5000; repeat: true; running: root.monitoringActive
        onTriggered: root.refreshAudioAndBrightness()
    }

    property Timer slowPoll: Timer {
        interval: 15000; repeat: true; running: root.monitoringActive
        onTriggered: root.refreshMediaAndAppearance()
    }

    property Timer wifiPoll: Timer {
        interval: 15000; repeat: true; running: root.monitoringActive
        onTriggered: exec.connectSource("nmcli radio wifi")
    }

}
