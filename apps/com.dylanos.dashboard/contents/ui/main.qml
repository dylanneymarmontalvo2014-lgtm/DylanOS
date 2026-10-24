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
    property date selectedDate: new Date()
    property date lastRefreshRequested: new Date(0)
    property int memoryUsed: 0
    property int memoryTotal: 0
    property real uptimeSeconds: 0
    property real cpuUsagePercent: -1
    property var cpuHistory: []
    property double previousCpuTotal: -1
    property double previousCpuIdle: -1
    property double diskUsedBytes: -1
    property double diskTotalBytes: -1
    property P5Support.DataSource commandRunner: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
    }
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
            } else if (sourceName === "cat /proc/stat") {
                const cpuLine = output.match(/^cpu\s+[0-9 ]+/m)
                const counters = cpuLine ? root.cpuCountersFromStatLine(cpuLine[0]) : null
                if (counters) {
                    const total = counters.total
                    const idle = counters.idle
                    if (root.previousCpuTotal >= 0) {
                        const totalDelta = total - root.previousCpuTotal
                        const idleDelta = idle - root.previousCpuIdle
                        if (totalDelta > 0 && idleDelta >= 0 && idleDelta <= totalDelta) {
                            root.cpuUsagePercent = Math.max(0, Math.min(100, 100 * (1 - idleDelta / totalDelta)))
                            root.cpuHistory = root.cpuHistory.concat([root.cpuUsagePercent]).slice(-24)
                        }
                    }
                    root.previousCpuTotal = total
                    root.previousCpuIdle = idle
                }
            } else if (sourceName === "df -B1 --output=used,size /") {
                const diskMatch = output.match(/^\s*(\d+)\s+(\d+)\s*$/m)
                if (diskMatch) {
                    root.diskUsedBytes = Number(diskMatch[1])
                    root.diskTotalBytes = Number(diskMatch[2])
                }
            }
        }
    }
    function cpuCountersFromStatLine(line) {
        const match = line.match(/^cpu\s+([0-9 ]+)/)
        if (!match) return null
        const ticks = match[1].trim().split(/\s+/).map(Number)
        if (ticks.length < 4 || ticks.some(value => !Number.isFinite(value) || value < 0)) return null
        // Linux incluye guest y guest_nice en user/nice; restarlos evita contarlos dos veces.
        const guestTicks = (ticks[8] || 0) + (ticks[9] || 0)
        const total = ticks.reduce((sum, value) => sum + value, 0) - guestTicks
        const idle = (ticks[3] || 0) + (ticks[4] || 0)
        return total >= idle ? { total: total, idle: idle } : null
    }
    function openSystemMonitor() {
        commandRunner.connectSource("plasma-systemmonitor")
    }
    function refreshSystemInfo() {
        root.lastRefreshRequested = new Date()
        procReader.connectSource("cat /proc/meminfo")
        procReader.connectSource("cat /proc/uptime")
        procReader.connectSource("cat /proc/stat")
        procReader.connectSource("df -B1 --output=used,size /")
    }
    function formatUptime(seconds) {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        return days > 0 ? days + " d · " + hours + " h" : hours + " h · " + minutes + " min"
    }
    function usagePercent(used, total) {
        if (total <= 0 || used < 0) return 0
        return Math.max(0, Math.min(100, used * 100 / total))
    }
    function progressWidth(trackWidth, used, total) {
        return trackWidth * usagePercent(used, total) / 100
    }
    function cpuHistoryDescription() {
        if (cpuHistory.length === 0) return "Tendencia de CPU: esperando lecturas"
        return "Tendencia de CPU: " + cpuHistory.length + " muestras; actual " + cpuHistory[cpuHistory.length - 1].toFixed(0) + "%"
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
    function isSameDate(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }
    function selectDate(date) {
        selectedDate = new Date(date.getFullYear(), date.getMonth(), date.getDate())
        if (selectedDate.getMonth() !== shownMonth.getMonth() || selectedDate.getFullYear() !== shownMonth.getFullYear())
            shownMonth = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
    }
    function showToday() {
        selectDate(new Date())
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
        implicitHeight: 360
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
                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Label { text: "ESTADO DEL SISTEMA"; color: "#AAA4AA"; font.pixelSize: 10; font.bold: true; Layout.fillWidth: true }
                    QQC2.ToolButton {
                        text: "Actualizar"
                        icon.name: "view-refresh"
                        Accessible.name: "Actualizar las métricas del sistema ahora"
                        onClicked: root.refreshSystemInfo()
                    }
                }
                QQC2.Label {
                    text: root.memoryTotal > 0
                        ? "Memoria  ·  " + root.usagePercent(root.memoryUsed, root.memoryTotal).toFixed(0) + "%  ·  " + (root.memoryUsed / 1048576).toFixed(1) + " / " + (root.memoryTotal / 1048576).toFixed(1) + " GiB"
                        : "Memoria  ·  No disponible"
                    color: "white"; font.pixelSize: 12
                }
                Rectangle {
                    Layout.fillWidth: true; height: 6; radius: 3; color: "#3CFFFFFF"
                    Accessible.name: "Uso de memoria: " + root.usagePercent(root.memoryUsed, root.memoryTotal).toFixed(0) + "%"
                    Rectangle {
                        width: root.progressWidth(parent.width, root.memoryUsed, root.memoryTotal)
                        height: parent.height; radius: 3; color: "#DC143C"
                        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    }
                }
                QQC2.Label {
                    text: root.cpuUsagePercent >= 0 ? "CPU  ·  " + root.cpuUsagePercent.toFixed(0) + "%" : "CPU  ·  leyendo…"
                    color: "white"; font.pixelSize: 12
                }
                Rectangle {
                    Layout.fillWidth: true; height: 6; radius: 3; color: "#3CFFFFFF"
                    Accessible.name: root.cpuUsagePercent >= 0 ? "Uso de CPU: " + root.cpuUsagePercent.toFixed(0) + "%" : "Uso de CPU sin datos"
                    Rectangle {
                        width: root.cpuUsagePercent >= 0 ? parent.width * Math.max(0, Math.min(100, root.cpuUsagePercent)) / 100 : 0
                        height: parent.height; radius: 3; color: "#DC143C"
                        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    }
                }
                QQC2.Label {
                    text: root.cpuHistory.length > 0
                        ? "TENDENCIA CPU · " + root.cpuHistory.length + "/24 muestras"
                        : "TENDENCIA CPU · esperando lecturas"
                    color: "#AAA4AA"; font.pixelSize: 9; font.bold: true
                    Accessible.name: root.cpuHistoryDescription()
                }
                Canvas {
                    id: cpuTrend
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    Accessible.ignored: true
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Connections {
                        target: root
                        function onCpuHistoryChanged() { cpuTrend.requestPaint() }
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        if (root.cpuHistory.length < 2 || width <= 0 || height <= 0) return
                        ctx.lineWidth = 1
                        ctx.strokeStyle = "rgba(255,255,255,0.12)"
                        for (let row = 1; row <= 3; row++) {
                            const y = height * row / 4
                            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                        }
                        const points = root.cpuHistory
                        const step = width / (points.length - 1)
                        ctx.beginPath()
                        for (let i = 0; i < points.length; i++) {
                            const x = i * step
                            const y = height - Math.max(0, Math.min(100, points[i])) * height / 100
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.strokeStyle = "#DC143C"
                        ctx.lineWidth = 2
                        ctx.lineJoin = "round"
                        ctx.lineCap = "round"
                        ctx.stroke()
                        const lastY = height - Math.max(0, Math.min(100, points[points.length - 1])) * height / 100
                        ctx.fillStyle = "#FF4565"
                        ctx.beginPath(); ctx.arc(width - 2, lastY, 2.5, 0, Math.PI * 2); ctx.fill()
                    }
                }
                QQC2.Label {
                    text: root.diskTotalBytes > 0
                        ? "Disco  ·  " + root.usagePercent(root.diskUsedBytes, root.diskTotalBytes).toFixed(0) + "%  ·  " + (root.diskUsedBytes / 1073741824).toFixed(1) + " / " + (root.diskTotalBytes / 1073741824).toFixed(1) + " GiB"
                        : "Disco  ·  no disponible"
                    color: "white"; font.pixelSize: 12
                }
                Rectangle {
                    Layout.fillWidth: true; height: 6; radius: 3; color: "#3CFFFFFF"
                    Accessible.name: root.diskTotalBytes > 0 ? "Uso del filesystem raíz: " + root.usagePercent(root.diskUsedBytes, root.diskTotalBytes).toFixed(0) + "%" : "Uso del filesystem raíz sin datos"
                    Rectangle {
                        width: root.progressWidth(parent.width, root.diskUsedBytes, root.diskTotalBytes)
                        height: parent.height; radius: 3; color: "#DC143C"
                        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    }
                }
                QQC2.Label {
                    text: root.uptimeSeconds > 0 ? "En ejecución  ·  " + root.formatUptime(root.uptimeSeconds) : "Tiempo activo  ·  …"
                    color: "#D7D2D6"; font.pixelSize: 12
                }
                QQC2.Label {
                    text: root.lastRefreshRequested.getTime() > 0
                        ? "Consulta · " + Qt.formatTime(root.lastRefreshRequested, "hh:mm:ss")
                        : "Consulta · esperando datos"
                    color: "#AAA4AA"; font.pixelSize: 10
                    Accessible.name: text
                }
                QQC2.Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    text: "Abrir Monitor del sistema"
                    icon.name: "utilities-system-monitor"
                    Accessible.name: "Abrir Monitor del sistema de KDE"
                    onClicked: root.openSystemMonitor()
                }
            }

            Rectangle { Layout.fillHeight: true; width: 1; color: "#26FFFFFF" }

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Label { text: root.monthTitle(root.shownMonth); color: "white"; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }
                    QQC2.ToolButton {
                        text: "Hoy"; Accessible.name: "Ir al día de hoy"
                        onClicked: root.showToday()
                    }
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
                        delegate: QQC2.Button {
                            id: calendarDay
                            required property int index
                            readonly property date dateValue: root.cellDate(index)
                            readonly property bool isToday: root.isSameDate(dateValue, root.today)
                            readonly property bool isSelected: root.isSameDate(dateValue, root.selectedDate)
                            implicitWidth: 25; implicitHeight: 25
                            padding: 0
                            Accessible.name: Qt.formatDate(dateValue, "dddd d MMMM yyyy")
                                + (isToday ? ", hoy" : "")
                                + (isSelected ? ", seleccionado" : "")
                            onClicked: root.selectDate(dateValue)
                            contentItem: QQC2.Label {
                                text: calendarDay.dateValue.getDate()
                                color: calendarDay.dateValue.getMonth() === root.shownMonth.getMonth() ? "white" : "#777177"
                                font.pixelSize: 11
                                font.bold: calendarDay.isSelected || calendarDay.isToday
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: width / 2
                                color: calendarDay.isSelected
                                    ? (calendarDay.down ? "#B01030" : calendarDay.hovered ? "#F02A50" : "#DC143C")
                                    : calendarDay.hovered ? "#24FFFFFF" : "transparent"
                                border.width: calendarDay.isToday && !calendarDay.isSelected ? 1 : 0
                                border.color: "#DC143C"
                                Behavior on color { ColorAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on border.width { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                QQC2.Label {
                    text: "Día seleccionado · " + Qt.formatDate(root.selectedDate, "dddd d MMMM")
                        + (root.isSameDate(root.selectedDate, root.today) ? " · hoy" : "")
                    color: "#D7D2D6"; font.pixelSize: 12; font.bold: true
                    Accessible.name: text
                }
                QQC2.Label { text: "Información local · sin datos simulados"; color: "#AAA4AA"; font.pixelSize: 10 }
            }
        }
    }
}
