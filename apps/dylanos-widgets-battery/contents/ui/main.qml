pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens
import "lib/WidgetData.js" as Data

/*
 * DylanOS Widgets — Batería.
 *
 * Lee el estado real de /sys/class/power_supply, la fuente que el kernel
 * expone y que también consulta UPower. Sin batería (equipo de sobremesa) el
 * widget lo dice explícitamente; no muestra un 100 % falso.
 *
 * El porcentaje y el estado se publican en una sola consulta para no lanzar
 * dos procesos por refresco.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small]
    readonly property string defaultSize: Tokens.small
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    // -1 = sin dato. Nunca se asume 0 % ni 100 %.
    property int percent: -1
    property string stateLabel: "Sin batería"

    readonly property bool low: root.percent >= 0 && root.percent <= 15
    readonly property color accent: root.low ? Tokens.crimson : Tokens.white

    Timer {
        id: poll
        interval: 60000
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
            root.applyReading(data.stdout || "");
        }
    }

    function refresh() {
        // Una sola invocación: recorre las baterías reales del equipo.
        reader.connectSource(
            "sh -c 'for b in /sys/class/power_supply/*/; do "
            + "[ \"$(cat $b/type 2>/dev/null)\" = Battery ] || continue; "
            + "printf \"%s|%s\\n\" \"$(cat $b/capacity 2>/dev/null)\" "
            + "\"$(cat $b/status 2>/dev/null)\"; done'");
    }

    function applyReading(text) {
        const line = String(text || "").split("\n").find(l => l.indexOf("|") !== -1);
        if (!line) {
            root.percent = -1;
            root.stateLabel = "Sin batería";
            return;
        }
        const parts = line.split("|");
        const value = parseInt(parts[0], 10);
        root.percent = isFinite(value) ? Math.max(0, Math.min(100, value)) : -1;
        root.stateLabel = root.translateState((parts[1] || "").trim());
    }

    function translateState(raw) {
        switch (raw) {
        case "Charging": return "Cargando";
        case "Discharging": return "Descargando";
        case "Full": return "Completa";
        case "Not charging": return "Enchufado, sin carga";
        case "Unknown": return "Estado desconocido";
        default: return raw.length > 0 ? raw : "Sin dato";
        }
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(Tokens.small, root.cellSize)
        implicitHeight: Tokens.heightFor(Tokens.small, root.cellSize)

        WidgetShell {
            anchors.fill: parent
            title: "Batería"

            Column {
                anchors.centerIn: parent
                spacing: Tokens.space1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.percent >= 0 ? root.percent + " %" : "—"
                    color: root.accent
                    font.family: Tokens.fontFamily
                    font.pixelSize: Math.round(root.cellSize * 0.28)
                    font.weight: Font.Light
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.stateLabel
                    color: Tokens.lightGray
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeCaption
                }

                WidgetMeter {
                    width: parent.width * 0.7
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: root.percent >= 0 ? root.percent / 100 : -1
                }
            }
        }
    }
}
