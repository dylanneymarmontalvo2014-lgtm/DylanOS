pragma Singleton
import QtQuick
import org.kde.plasma.plasma5support as P5Support
import org.kde.bluezqt as BluezQt

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
 * "No molestar" es LOCAL a este widget (oculta notificaciones nuevas aquí),
 * no es un DND global del sistema — eso requiere una API privada inestable.
 */
QtObject {
    id: root

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

    // =====================================================================
    // MODO OSCURO (plasma-apply-colorscheme)
    // =====================================================================
    property bool darkModeActive: true

    function toggleDarkMode() {
        const target = !darkModeActive
        darkModeActive = target // respuesta inmediata en UI
        exec.connectSource("plasma-apply-colorscheme " + (target ? "BreezeDark" : "BreezeLight"))
    }

    // =====================================================================
    // NO MOLESTAR (local al widget)
    // =====================================================================
    property bool doNotDisturb: false
    function toggleDoNotDisturb() { doNotDisturb = !doNotDisturb }

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

            // ---- Modo oscuro ----
            } else if (sourceName.indexOf("kreadconfig6") === 0) {
                root.darkModeActive = out.toLowerCase().indexOf("dark") !== -1

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
    // POLLING (cada 2s: brillo/volumen/mpris/darkmode. Wi-Fi cada 5s)
    // =====================================================================
    function refreshAll() {
        exec.connectSource("qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightnessMax")
        exec.connectSource("qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightness")
        exec.connectSource("pactl get-sink-volume @DEFAULT_SINK@")
        exec.connectSource("pactl get-sink-mute @DEFAULT_SINK@")
        exec.connectSource("kreadconfig6 --file kdeglobals --group General --key ColorScheme")
        exec.connectSource("playerctl status")
    }

    property Timer fastPoll: Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: root.refreshAll()
    }

    property Timer wifiPoll: Timer {
        interval: 5000; repeat: true; running: true
        onTriggered: exec.connectSource("nmcli radio wifi")
    }

    Component.onCompleted: {
        refreshAll()
        exec.connectSource("nmcli radio wifi")
    }
}
