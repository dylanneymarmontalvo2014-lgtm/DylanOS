import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: monitorPage
    property bool paused: false
    spacing: 16
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            Label { text: "Todo bajo control."; font.pixelSize: 30; font.weight: Font.DemiBold; font.letterSpacing: -1 }
            Label { text: backend.stats.host + " · " + backend.stats.uptime + " de actividad"; color: palette.placeholderText; font.pixelSize: 12 }
        }
        Item { Layout.fillWidth: true }
        ActionButton { text: monitorPage.paused ? "Reanudar" : "Pausar"; onClicked: { monitorPage.paused = !monitorPage.paused; backend.pauseMonitor(monitorPage.paused) } }
        ActionButton { text: "Monitor avanzado  ↗"; onClicked: backend.action("monitor") }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 14
        Repeater {
            model: [
                {label:"PROCESADOR", value:backend.stats.cpu, detail:"Uso actual de CPU", color:"#f2839e", history:backend.stats.cpuHistory},
                {label:"MEMORIA", value:backend.stats.memory, detail:backend.stats.memoryText, color:"#b6a0ec", history:backend.stats.memoryHistory},
                {label:"ALMACENAMIENTO", value:backend.stats.disk, detail:backend.stats.free + " disponibles", color:"#93cac3", history:[]}
            ]
            delegate: Surface {
                required property var modelData
                Layout.fillWidth: true; Layout.preferredWidth: 220
                ColumnLayout {
                    width: parent.width; spacing: 16
                    Label { text: modelData.label; font.pixelSize: 9; font.letterSpacing: 1.4; color: palette.placeholderText }
                    Label { text: modelData.value + "%"; font.pixelSize: 39; font.weight: Font.Light; color: modelData.color }
                    HistoryChart { Layout.fillWidth: true; Layout.preferredHeight: 48; samples: modelData.history; lineColor: modelData.color; opacity: modelData.history.length > 0 ? 1 : 0 }
                    ProgressBar {
                        id: usage; value: modelData.value / 100; Layout.fillWidth: true
                        implicitHeight: 5
                        background: Rectangle { radius: 3; color: usage.palette.mid }
                        contentItem: Item { Rectangle { width: usage.visualPosition * parent.width; height: parent.height; radius: 3; color: modelData.color; Behavior on width { NumberAnimation { duration: 220 } } } }
                    }
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
                Label { text: "Procesos · " + backend.stats.processCount; font.pixelSize: 19; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Label { text: monitorPage.paused ? "EN PAUSA" : "MAYOR USO DE MEMORIA · CADA 2,5 S"; color: palette.placeholderText; font.pixelSize: 9; font.letterSpacing: 0.8 }
            }
            Field { id: processSearch; Layout.fillWidth: true; placeholderText: "Buscar por nombre o PID"; Accessible.name: placeholderText }
            ListView {
                id: processList; model: (backend.stats.processes || []).filter(p => (p.name + " " + p.pid).toLowerCase().includes(processSearch.text.toLowerCase())); Layout.fillHeight: true; Layout.fillWidth: true; clip: true
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
