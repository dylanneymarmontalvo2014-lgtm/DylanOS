pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Red y Wi-Fi.
 *
 * Estado real de NetworkManager con `nmcli`, el mismo cliente que usa DylanOS
 * Configuration. Sin conexión activa lo dice explícitamente.
 *
 * Refresco cada 30 s y también al abrir el widget: nmcli tarda ~50 ms y no
 * tiene sentido sondear más rápido para un dato que cambia al conectar.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small]
    readonly property string defaultSize: Tokens.small
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    property string connection: ""
    property string device: ""
    property string ipv4: ""

    readonly property bool connected: root.connection.length > 0
    readonly property bool wireless: root.device.indexOf("wifi") === 0
    readonly property color accent: root.connected ? Tokens.white : Tokens.lightGray

    Timer {
        id: poll
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    P5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            if (sourceName === "nmcli -t -f NAME,TYPE,DEVICE connection show --active") {
                root.parseActive(data.stdout || "");
            } else if (sourceName.indexOf("IP4.ADDRESS") !== -1) {
                const value = String(data.stdout || "").trim();
                root.ipv4 = value.length > 0 ? value.split("/")[0] : "";
            }
        }
    }

    function refresh() {
        reader.connectSource("nmcli -t -f NAME,TYPE,DEVICE connection show --active");
    }

    function parseActive(text) {
        const lines = String(text || "").split("\n").filter(l => l.length > 0);
        // Se prefiere una conexión de tipo wifi/ethernet sobre el marcador
        // "lo" (loopback), que siempre existe pero no es una conexión de red.
        let chosen = null;
        for (let i = 0; i < lines.length; ++i) {
            const parts = lines[i].split(":");
            const type = parts[1] || "";
            if (type === "loopback")
                continue;
            if (chosen === null || type === "wifi" || type === "802-11-wireless")
                chosen = parts;
            if (type === "wifi" || type === "802-11-wireless")
                break;
        }
        if (chosen === null) {
            root.connection = "";
            root.device = "";
            root.ipv4 = "";
            return;
        }
        root.connection = chosen[0] || "";
        root.device = chosen[2] || "";
        root.ipv4 = "";
        if (root.device.length > 0) {
            reader.connectSource("nmcli -t -f IP4.ADDRESS device show " + root.device);
        }
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(Tokens.small, root.cellSize)
        implicitHeight: Tokens.heightFor(Tokens.small, root.cellSize)

        WidgetShell {
            anchors.fill: parent
            title: root.wireless ? "Wi-Fi" : "Red"
            actionIcon: "\u21bb"
            onActionClicked: root.refresh()

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Tokens.space1

                Text {
                    width: parent.width
                    text: root.connected ? root.connection : "Sin conexión"
                    color: root.accent
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.connected
                          ? (root.ipv4.length > 0 ? root.ipv4 : "Sin dirección IPv4")
                          : "NetworkManager no reporta conexión activa"
                    color: Tokens.lightGray
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeCaption
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }
    }
}
