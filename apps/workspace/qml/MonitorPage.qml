import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    spacing: 20
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            Label { text: "Todo bajo control."; font.pixelSize: 30; font.weight: Font.DemiBold; font.letterSpacing: -1 }
            Label { text: backend.stats.host + " · " + backend.stats.uptime + " de actividad"; color: palette.placeholderText; font.pixelSize: 12 }
        }
        ActionButton { text: "Monitor avanzado  ↗"; onClicked: backend.action("monitor") }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 14
        Repeater {
            model: [
                {label:"PROCESADOR", value:backend.stats.cpu, detail:"Uso actual de CPU", color:"#c4a5ef"},
                {label:"MEMORIA", value:backend.stats.memory, detail:backend.stats.memoryText, color:"#ef9bab"},
                {label:"ALMACENAMIENTO", value:backend.stats.disk, detail:backend.stats.free + " disponibles", color:"#93cac3"}
            ]
            delegate: Surface {
                required property var modelData
                Layout.fillWidth: true; Layout.preferredWidth: 220
                ColumnLayout {
                    width: parent.width; spacing: 16
                    Label { text: modelData.label; font.pixelSize: 9; font.letterSpacing: 1.4; color: palette.placeholderText }
                    Label { text: modelData.value + "%"; font.pixelSize: 39; font.weight: Font.Light; color: modelData.color }
                    ProgressBar { value: modelData.value / 100; Layout.fillWidth: true }
                    Label { text: modelData.detail; font.pixelSize: 11; color: palette.placeholderText; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
        }
    }
    Surface {
        Layout.fillWidth: true; Layout.fillHeight: true
        ColumnLayout {
            anchors.fill: parent; spacing: 14
            RowLayout {
                Label { text: "Procesos"; font.pixelSize: 19; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Label { text: "MAYOR USO DE MEMORIA · CADA 2,5 S"; color: palette.placeholderText; font.pixelSize: 9; font.letterSpacing: 0.8 }
            }
            ListView {
                id: processList; model: backend.stats.processes; Layout.fillHeight: true; Layout.fillWidth: true; clip: true
                ScrollBar.vertical: ScrollBar {}
                delegate: RowLayout {
                    required property var modelData
                    width: processList.width; height: 42
                    Label { text: modelData.pid; color: palette.placeholderText; Layout.preferredWidth: 65; font.pixelSize: 11 }
                    Label { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 13 }
                    Label { text: modelData.memory; font.pixelSize: 12 }
                }
            }
        }
    }
    Label { text: "Kernel " + backend.stats.kernel + "  ·  " + backend.stats.battery; color: palette.placeholderText; font.pixelSize: 11 }
}
