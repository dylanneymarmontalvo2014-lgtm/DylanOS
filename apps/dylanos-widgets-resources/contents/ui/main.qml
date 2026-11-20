pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens
import "lib/WidgetData.js" as Data

/*
 * DylanOS Widgets — CPU y RAM.
 *
 * Métricas reales de /proc/stat y /proc/meminfo, con las mismas fórmulas que
 * DylanOS Configuration (SystemService::sysInfo): los contadores guest y
 * guest_nice no se suman dos veces y un delta incoherente se descarta en vez
 * de mostrar un porcentaje inválido.
 *
 * El refresco es de 5 s y solo mientras el widget es visible: no hay sondeo
 * de fondo cuando el escritorio está tapado.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small, Tokens.mediumWide]
    readonly property string defaultSize: Tokens.small
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell
    readonly property bool wide: width > height * 1.4

    preferredRepresentation: fullRepresentation

    property real cpuPercent: -1
    property real memUsedKb: -1
    property real memTotalKb: -1
    property double previousTotal: -1
    property double previousIdle: -1

    readonly property real memRatio: memTotalKb > 0 ? memUsedKb / memTotalKb : -1
    readonly property int memGb: memTotalKb > 0 ? Data.roundMemoryGb(memTotalKb) : 0

    Timer {
        id: poll
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    P5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const out = data.stdout || "";
            if (sourceName === "cat /proc/stat") {
                root.updateCpu(out);
            } else if (sourceName === "cat /proc/meminfo") {
                const mem = Data.parseMemInfo(out);
                if (mem) {
                    root.memTotalKb = mem.totalKb;
                    root.memUsedKb = mem.usedKb;
                }
            }
        }
    }

    function sample() {
        reader.connectSource("cat /proc/stat");
        reader.connectSource("cat /proc/meminfo");
    }

    function updateCpu(text) {
        const match = String(text).match(/^cpu\s+[0-9 ]+/m);
        if (!match)
            return;
        const counters = Data.cpuCountersFromStatLine(match[0]);
        if (!counters)
            return;
        const usage = Data.cpuUsagePercent(root.previousTotal, root.previousIdle,
                                           counters.total, counters.idle);
        if (usage !== null)
            root.cpuPercent = usage;
        root.previousTotal = counters.total;
        root.previousIdle = counters.idle;
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(root.wide ? Tokens.mediumWide : Tokens.small,
                                       root.cellSize)
        implicitHeight: root.cellSize

        WidgetShell {
            anchors.fill: parent
            title: "Sistema"

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Tokens.space1

                Text {
                    width: parent.width
                    text: "CPU  " + Data.formatPercent(root.cpuPercent)
                    color: PlasmaCore.Theme.textColor
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeBody
                }

                WidgetMeter {
                    width: parent.width
                    value: root.cpuPercent >= 0 ? root.cpuPercent / 100 : -1
                }

                Item { width: 1; height: Tokens.space1 }

                Text {
                    width: parent.width
                    text: "RAM  " + (root.memTotalKb > 0
                                     ? root.memGb + " GB · " + Math.round(root.memRatio * 100) + " %"
                                     : "—")
                    color: PlasmaCore.Theme.textColor
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeBody
                }

                WidgetMeter {
                    width: parent.width
                    value: root.memRatio >= 0 ? root.memRatio : -1
                }
            }
        }
    }
}
