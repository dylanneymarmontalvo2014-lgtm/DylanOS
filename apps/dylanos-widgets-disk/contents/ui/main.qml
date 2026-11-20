pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens
import "lib/WidgetData.js" as Data

/*
 * DylanOS Widgets — Espacio en disco.
 *
 * Uso real del sistema de archivos raíz con `df -B1` (la misma consulta que
 * usa el Dashboard histórico). Refresco de 5 minutos: el espacio libre no
 * cambia lo bastante como para sondearlo con frecuencia.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small, Tokens.mediumWide]
    readonly property string defaultSize: Tokens.small
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    property double usedBytes: -1
    property double totalBytes: -1

    readonly property real ratio: totalBytes > 0 ? usedBytes / totalBytes : -1

    Timer {
        id: poll
        interval: 300000
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
            const parsed = Data.parseDfOutput(data.stdout || "");
            if (parsed) {
                root.usedBytes = parsed.usedBytes;
                root.totalBytes = parsed.totalBytes;
            }
        }
    }

    function refresh() {
        reader.connectSource("df -B1 --output=used,size /");
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(Tokens.small, root.cellSize)
        implicitHeight: Tokens.heightFor(Tokens.small, root.cellSize)

        WidgetShell {
            anchors.fill: parent
            title: "Disco"

            Column {
                anchors.centerIn: parent
                spacing: Tokens.space1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.ratio >= 0 ? Math.round(root.ratio * 100) + " %" : "—"
                    color: PlasmaCore.Theme.textColor
                    font.family: Tokens.fontFamily
                    font.pixelSize: Math.round(root.cellSize * 0.26)
                    font.weight: Font.Light
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.totalBytes > 0
                          ? Data.formatBytes(root.usedBytes) + " de "
                            + Data.formatBytes(root.totalBytes)
                          : "Sin dato"
                    color: PlasmaCore.Theme.disabledTextColor
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeCaption
                }

                WidgetMeter {
                    width: parent.width * 0.7
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: root.ratio
                }
            }
        }
    }
}
