import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    readonly property date today: clock.date
    property date shownMonth: new Date()
    property int memoryUsed: 0
    property int memoryTotal: 0
    property real uptimeSeconds: 0
    property P5Support.DataSource procReader: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            const output = (data.stdout || "")
            if (sourceName === "cat /proc/meminfo") {
                const totalMatch = output.match(/MemTotal:\s+(\d+)/)
                const availableMatch = output.match(/MemAvailable:\s+(\d+)/)
                if (totalMatch) root.memoryTotal = Number(totalMatch[1])
                if (totalMatch && availableMatch) root.memoryUsed = Number(totalMatch[1]) - Number(availableMatch[1])
            } else if (sourceName === "cat /proc/uptime") {
                const uptimeMatch = output.match(/^([0-9]+(?:\.[0-9]+)?)/)
                if (uptimeMatch) root.uptimeSeconds = Number(uptimeMatch[1])
            }
        }
    }
    function refreshSystemInfo() {
        procReader.connectSource("cat /proc/meminfo")
        procReader.connectSource("cat /proc/uptime")
    }
    function formatUptime(seconds) {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        return days > 0 ? days + " d · " + hours + " h" : hours + " h · " + minutes + " min"
    }
    function monthTitle(date) { return Qt.formatDate(date, "MMMM yyyy") }
    function cellDate(index) {
        const first = new Date(shownMonth.getFullYear(), shownMonth.getMonth(), 1)
        const mondayOffset = (first.getDay() + 6) % 7
        return new Date(shownMonth.getFullYear(), shownMonth.getMonth(), index - mondayOffset + 1)
    }
    function shiftMonth(offset) {
        shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + offset, 1)
    }

    Timer {
        id: clock
        property date date: new Date()
        interval: 30000
        repeat: true
        running: true
        onTriggered: date = new Date()
    }
    Timer { interval: 10000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refreshSystemInfo() }

    fullRepresentation: Rectangle {
        implicitWidth: 500
        implicitHeight: 300
        radius: 24
        color: "#E6101014"
        border.color: "#40FFFFFF"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 22

            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: 205
                spacing: 8
                Rectangle { width: 38; height: 3; radius: 2; color: "#DC143C" }
                QQC2.Label {
                    text: Qt.formatTime(root.today, "h:mm AP")
                    color: "white"; font.pixelSize: 42; font.weight: Font.DemiBold
                    Accessible.name: "Hora actual"
                }
                QQC2.Label {
                    text: Qt.formatDate(root.today, "dddd, d MMMM")
                    color: "#D7D2D6"; font.pixelSize: 14
                }
                Item { Layout.fillHeight: true }
                QQC2.Label { text: "ESTADO DEL SISTEMA"; color: "#AAA4AA"; font.pixelSize: 10; font.bold: true }
                QQC2.Label {
                    text: root.memoryTotal > 0
                        ? "Memoria  ·  " + (root.memoryUsed / 1048576).toFixed(1) + " / " + (root.memoryTotal / 1048576).toFixed(1) + " GiB"
                        : "Memoria  ·  No disponible"
                    color: "white"; font.pixelSize: 12
                }
                Rectangle {
                    Layout.fillWidth: true; height: 5; radius: 3; color: "#3CFFFFFF"
                    Rectangle {
                        width: root.memoryTotal > 0 ? parent.width * root.memoryUsed / root.memoryTotal : 0
                        height: parent.height; radius: 3; color: "#DC143C"
                    }
                }
                QQC2.Label {
                    text: root.uptimeSeconds > 0 ? "En ejecución  ·  " + root.formatUptime(root.uptimeSeconds) : "Tiempo activo  ·  …"
                    color: "#D7D2D6"; font.pixelSize: 12
                }
            }

            Rectangle { Layout.fillHeight: true; width: 1; color: "#26FFFFFF" }

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Label { text: root.monthTitle(root.shownMonth); color: "white"; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }
                    QQC2.ToolButton {
                        text: "‹"; Accessible.name: "Mes anterior"; onClicked: root.shiftMonth(-1)
                        contentItem: QQC2.Label { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    QQC2.ToolButton {
                        text: "›"; Accessible.name: "Mes siguiente"; onClicked: root.shiftMonth(1)
                        contentItem: QQC2.Label { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7; rowSpacing: 5; columnSpacing: 4
                    Repeater {
                        model: ["L", "M", "X", "J", "V", "S", "D"]
                        delegate: QQC2.Label {
                            required property string modelData
                            text: modelData; color: "#AAA4AA"; font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                    }
                    Repeater {
                        model: 42
                        delegate: Rectangle {
                            required property int index
                            readonly property date dateValue: root.cellDate(index)
                            implicitWidth: 25; implicitHeight: 25; radius: 13
                            color: dateValue.getFullYear() === root.today.getFullYear() && dateValue.getMonth() === root.today.getMonth() && dateValue.getDate() === root.today.getDate() ? "#DC143C" : "transparent"
                            QQC2.Label {
                                anchors.centerIn: parent
                                text: parent.dateValue.getDate()
                                color: parent.dateValue.getMonth() === root.shownMonth.getMonth() ? "white" : "#777177"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                QQC2.Label { text: "Información local · sin datos simulados"; color: "#AAA4AA"; font.pixelSize: 10 }
            }
        }
    }
}
