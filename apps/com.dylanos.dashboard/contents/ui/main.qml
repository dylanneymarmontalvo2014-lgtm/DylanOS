pragma ComponentBehavior: Bound
// DylanOS Dashboard 0.8.0 — muro de widgets del escritorio.
// Cada sección es una tarjeta independiente de vidrio oscuro con borde sutil
// y reflejo superior (línea especular translúcida), como en el preview
// `previews/DylanOS shell/escritorio_preview.png`. Todo el contenido es real:
// el calendario y las métricas leen /proc y df; los recordatorios se guardan
// en la configuración de Plasma del applet; "En reproducción" usa playerctl
// (MPRIS) y el temporizador de enfoque calcula con la hora del sistema. No
// consulta servicios remotos ni muestra clima ni eventos ficticios.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "PomodoroClock.js" as PomodoroClock

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
    property string pomodoroMode: "focus"
    property int pomodoroRemainingSeconds: 25 * 60
    property int completedFocusSessions: 0
    property bool pomodoroRunning: false
    property bool pomodoroStarted: false
    property bool pomodoroComplete: false
    property double pomodoroDeadlineMs: 0
    readonly property int pomodoroDurationSeconds: PomodoroClock.durationSeconds(pomodoroMode)
    readonly property string pomodoroStatus: pomodoroComplete
        ? (pomodoroMode === "focus" ? "Enfoque listo · descanso de 5 min" : "Descanso listo · vuelve a enfocarte")
        : pomodoroRunning ? (pomodoroMode === "focus" ? "Enfoque en curso" : "Descanso en curso")
        : pomodoroStarted ? "Temporizador en pausa" : "Listo para empezar"
    // Recordatorios: lista local del usuario, persistida en la configuración
    // del applet (KConfigXT). Empieza vacía; nada se inventa.
    property string reminderState: Plasmoid.configuration.recordatorios
    // Reproducción real vía playerctl (MPRIS). Sin reproductor, la tarjeta
    // permanece inactiva y lo indica.
    property bool mprisAvailable: false
    property bool mprisPlaying: false
    property string mediaTitle: ""
    property string mediaArtist: ""
    property double mediaPositionSeconds: 0
    property double mediaDurationSeconds: 0
    readonly property bool mediaKnownDuration: mediaDurationSeconds > 0
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
    // Fuente de medios: consulta estado y metadatos del reproductor MPRIS
    // activo mediante playerctl (instalado en el perfil base de DylanOS).
    property P5Support.DataSource mediaRunner: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            const output = (data.stdout || "").trim()
            const stderr = (data.stderr || "").trim()
            if (sourceName === "playerctl status") {
                root.mprisAvailable = (stderr === "" && (output === "Playing" || output === "Paused"))
                root.mprisPlaying = (output === "Playing")
                if (root.mprisAvailable) root.mediaRunner.connectSource("playerctl metadata --format {{position}}|||{{duration}}|||{{title}}|||{{artist}}")
                else {
                    root.mediaTitle = ""
                    root.mediaArtist = ""
                    root.mediaPositionSeconds = 0
                    root.mediaDurationSeconds = 0
                }
            } else if (sourceName.indexOf("playerctl metadata") === 0) {
                const parts = output.split("|||")
                const position = Number.parseFloat(parts[0])
                const duration = Number.parseFloat(parts[1])
                if (Number.isFinite(position) && position >= 0) root.mediaPositionSeconds = position
                root.mediaDurationSeconds = Number.isFinite(duration) && duration > 0 ? duration : 0
                root.mediaTitle = parts.length > 2 ? parts[2] : ""
                root.mediaArtist = parts.length > 3 ? parts[3] : ""
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
    function titleCase(text) {
        return text.length > 0 ? text.charAt(0).toUpperCase() + text.slice(1) : text
    }
    function clockParts(date) {
        const formatted = Qt.formatTime(date, "h:mm AP")
        const divider = formatted.lastIndexOf(" ")
        return divider > 0
            ? { time: formatted.substring(0, divider), ampm: formatted.substring(divider + 1) }
            : { time: formatted, ampm: "" }
    }
    function padClockTime(text) {
        return text.length === 4 ? "0" + text : text
    }
    function monthTitle(date) { return titleCase(Qt.formatDate(date, "MMMM yyyy")) }
    function cellDate(index) {
        const first = new Date(shownMonth.getFullYear(), shownMonth.getMonth(), 1)
        // Semana que empieza en domingo (D L M M J V S), como en el preview.
        const sundayOffset = first.getDay()
        return new Date(shownMonth.getFullYear(), shownMonth.getMonth(), index - sundayOffset + 1)
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
    // ===== Recordatorios: parseo y escritura del estado persistente =====
    function parseReminders(unparsed) {
        const result = []
        try {
            const decoded = JSON.parse(unparsed || "[]")
            if (Array.isArray(decoded)) {
                for (let i = 0; i < decoded.length && i < 100; i++) {
                    const entry = decoded[i]
                    if (entry && typeof entry.t === "string") {
                        const text = entry.t.replace(/\s+/g, " ").trim().slice(0, 120)
                        if (text !== "") result.push({ t: text, d: entry.d === true })
                    }
                }
            }
        } catch (e) {
            return []
        }
        return result
    }
    readonly property var reminders: parseReminders(reminderState)
    function writeReminders(list) {
        const clean = []
        for (let i = 0; i < list.length && i < 100; i++) {
            const entry = list[i]
            const text = (typeof entry.t === "string" ? entry.t : "").replace(/\s+/g, " ").trim().slice(0, 120)
            if (text !== "") clean.push({ t: text, d: entry.d === true })
        }
        Plasmoid.configuration.recordatorios = JSON.stringify(clean)
    }
    function addReminder(text) {
        const clean = (text || "").replace(/\s+/g, " ").trim()
        if (clean === "" || clean.length > 120) return
        writeReminders(reminders.concat([{ t: clean, d: false }]))
    }
    function toggleReminder(index) {
        if (index < 0 || index >= reminders.length) return
        const list = reminders.map(entry => ({ t: entry.t, d: entry.d }))
        list[index].d = !list[index].d
        writeReminders(list)
    }
    function removeReminder(index) {
        if (index < 0 || index >= reminders.length) return
        writeReminders(reminders.filter((entry, i) => i !== index).map(entry => ({ t: entry.t, d: entry.d })))
    }
    function renameReminder(index, text) {
        const clean = (text || "").replace(/\s+/g, " ").trim()
        if (index < 0 || index >= reminders.length) return
        if (clean === "") { removeReminder(index); return }
        const list = reminders.map(entry => ({ t: entry.t, d: entry.d }))
        list[index].t = clean.slice(0, 120)
        writeReminders(list)
    }
    // ===== Controles del reproductor (playerctl, acciones reales) =====
    function refreshMediaState() {
        mediaRunner.connectSource("playerctl status")
    }
    function mediaPlayPause() { mediaRunner.connectSource("playerctl play-pause") }
    function mediaNext() { mediaRunner.connectSource("playerctl next") }
    function mediaPrevious() { mediaRunner.connectSource("playerctl previous") }
    function seekMedia(normalized) {
        if (mediaDurationSeconds <= 0) return
        mediaRunner.connectSource("playerctl position " + Math.max(0, Math.round(normalized * mediaDurationSeconds)))
    }
    function formatMediaTime(seconds) {
        const whole = Math.max(0, Math.round(Number.isFinite(seconds) ? seconds : 0))
        return Math.floor(whole / 60) + ":" + ("0" + (whole % 60)).slice(-2)
    }
    function startPomodoro() {
        if (pomodoroComplete) {
            pomodoroMode = PomodoroClock.nextMode(pomodoroMode)
            pomodoroRemainingSeconds = PomodoroClock.durationSeconds(pomodoroMode)
            pomodoroComplete = false
            pomodoroStarted = false
        }
        if (pomodoroRemainingSeconds <= 0) {
            pomodoroRemainingSeconds = PomodoroClock.durationSeconds(pomodoroMode)
        }
        pomodoroDeadlineMs = Date.now() + pomodoroRemainingSeconds * 1000
        pomodoroRunning = true
        pomodoroStarted = true
    }
    function pausePomodoro() {
        if (!pomodoroRunning) return
        pomodoroRemainingSeconds = PomodoroClock.remainingSeconds(pomodoroDeadlineMs, Date.now())
        if (pomodoroRemainingSeconds <= 0) {
            updatePomodoro()
            return
        }
        pomodoroRunning = false
        pomodoroDeadlineMs = 0
    }
    function resetPomodoro() {
        pomodoroRunning = false
        pomodoroStarted = false
        pomodoroComplete = false
        pomodoroDeadlineMs = 0
        pomodoroRemainingSeconds = PomodoroClock.durationSeconds(pomodoroMode)
    }
    function updatePomodoro() {
        if (!pomodoroRunning) return
        pomodoroRemainingSeconds = PomodoroClock.remainingSeconds(pomodoroDeadlineMs, Date.now())
        if (pomodoroRemainingSeconds > 0) return
        pomodoroRunning = false
        pomodoroStarted = true
        pomodoroComplete = true
        pomodoroDeadlineMs = 0
        if (pomodoroMode === "focus") completedFocusSessions++
    }
    function formatPomodoroTime(seconds) {
        const safeSeconds = Math.max(0, seconds)
        const minutes = Math.floor(safeSeconds / 60)
        const remainder = safeSeconds % 60
        return (minutes < 10 ? "0" : "") + minutes + ":" + (remainder < 10 ? "0" : "") + remainder
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
    Timer { interval: 1000; repeat: true; running: root.pomodoroRunning; onTriggered: root.updatePomodoro() }
    // Reproducción: estado cada 15 s; posición mientras suena, cada 2 s.
    Timer { interval: 15000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refreshMediaState() }
    Timer {
        interval: 2000
        repeat: true
        running: root.mprisPlaying
        onTriggered: root.mediaRunner.connectSource("playerctl metadata --format {{position}}|||{{duration}}|||{{title}}|||{{artist}}")
    }

    // ===== Tarjeta base de vidrio oscuro =====
    component WidgetCard: Rectangle {
        id: card
        property string cardTitle: ""
        default property alias content: cardBody.children
        property alias headerExtra: headerExtra.data
        color: "#D9101014"
        radius: 22
        border.color: "#30FFFFFF"
        border.width: 1

        // Reflejo superior: línea especular blanca translúcida.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.075) }
                GradientStop { position: 0.42; color: Qt.rgba(1, 1, 1, 0.018) }
                GradientStop { position: 1; color: "transparent" }
            }
            opacity: 0.72
            Accessible.ignored: true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                visible: card.cardTitle !== ""
                Layout.fillWidth: true
                spacing: 10
                QQC2.Label {
                    text: card.cardTitle
                    color: "#FF7188"
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 0.6
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                    Layout.fillWidth: true
                }
                // Acciones de la cabecera (p. ej. «Actualizar», «+»).
                RowLayout { id: headerExtra; spacing: 4 }
            }

            ColumnLayout {
                id: cardBody
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
            }
        }
    }

    // ===== Aro circular de porcentaje (lecturas reales) =====
    component RingGauge: Item {
        id: gauge
        property real portion: 0            // 0..1, fracción real medida
        property string caption: "CPU"
        property bool sampled: true
        implicitWidth: 92
        implicitHeight: 92
        Accessible.role: Accessible.Gauge
        Accessible.name: sampled
            ? "Uso de " + caption + ": " + Math.round(portion * 100) + "%"
            : "Uso de " + caption + " sin datos"

        Canvas {
            id: ringDial
            anchors.fill: parent
            antialiasing: true
            Connections {
                target: gauge
                function onPortionChanged() { ringDial.requestPaint() }
                function onSampledChanged() { ringDial.requestPaint() }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                if (width <= 0 || height <= 0) return
                ctx.clearRect(0, 0, width, height)
                const center = width / 2
                const radius = Math.min(width, height) / 2 - 7
                ctx.lineWidth = 7
                ctx.lineCap = "round"
                // Pista circular tenue.
                ctx.strokeStyle = "rgba(255,255,255,0.16)"
                ctx.beginPath()
                ctx.arc(center, height / 2, radius, 0, Math.PI * 2)
                ctx.stroke()
                // Arco crimson con la lectura medida; sin datos no dibuja arco.
                if (gauge.sampled && gauge.portion > 0) {
                    const sweep = Math.min(2 * Math.PI, Math.max(0.07, gauge.portion * 2 * Math.PI))
                    ctx.strokeStyle = "#DC143C"
                    ctx.beginPath()
                    ctx.arc(center, height / 2, radius, -Math.PI / 2, -Math.PI / 2 + sweep)
                    ctx.stroke()
                }
            }
        }

        QQC2.Label {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -1
            text: gauge.sampled ? (Math.round(Math.max(0, Math.min(1, gauge.portion)) * 100)).toFixed(0) + "%" : "…"
            color: "white"
            font.pixelSize: 17
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }
        QQC2.Label {
            text: gauge.caption
            color: "#AAA4AA"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -3
        }
    }

    // ===== Representación completa: dos columnas de tarjetas =====
    fullRepresentation: Item {
        implicitWidth: 720
        implicitHeight: 700

        RowLayout {
            anchors.fill: parent
            spacing: 16

            // --------- Columna izquierda ---------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                // Reloj — lectura del reloj del sistema, sin datos inventados.
                WidgetCard {
                    cardTitle: ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    Layout.minimumHeight: 96
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            QQC2.Label {
                                text: root.padClockTime(root.clockParts(root.today).time)
                                color: "white"
                                font.pixelSize: 44
                                font.weight: Font.Light
                                font.letterSpacing: 2
                                Accessible.name: "Hora actual: " + Qt.formatTime(root.today, "h:mm AP")
                            }
                            QQC2.Label {
                                text: root.clockParts(root.today).ampm
                                color: "#DC143C"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                Layout.alignment: Qt.AlignBottom | Qt.AlignRight
                                Layout.bottomMargin: 10
                                Accessible.name: text
                                visible: text !== ""
                            }
                            Item { Layout.fillWidth: true }
                        }
                        QQC2.Label {
                            text: root.titleCase(Qt.formatDate(root.today, "dddd, dd MMMM"))
                            color: "#DC143C"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            Accessible.name: "Fecha: " + text
                        }
                    }
                }

                // Sistema — métricas reales de /proc y df.
                WidgetCard {
                    cardTitle: "Sistema"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 296
                    headerExtra: [
                        QQC2.ToolButton {
                            text: "Actualizar"
                            icon.name: "view-refresh"
                            Accessible.name: "Actualizar las métricas del sistema ahora"
                            onClicked: root.refreshSystemInfo()
                        }
                    ]
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        RingGauge {
                            portion: root.cpuUsagePercent >= 0 ? root.cpuUsagePercent / 100 : 0
                            sampled: root.cpuUsagePercent >= 0
                            caption: "CPU"
                            Layout.alignment: Qt.AlignTop
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: root.memoryTotal > 0
                                    ? "RAM  ·  " + root.usagePercent(root.memoryUsed, root.memoryTotal).toFixed(0) + "%  ·  " + (root.memoryUsed / 1048576).toFixed(1) + " / " + (root.memoryTotal / 1048576).toFixed(1) + " GiB"
                                    : "RAM  ·  No disponible"
                                color: "white"; font.pixelSize: 12
                                elide: Text.ElideRight
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
                                Layout.fillWidth: true
                                text: root.diskTotalBytes > 0
                                    ? "Disco  ·  " + root.usagePercent(root.diskUsedBytes, root.diskTotalBytes).toFixed(0) + "%  ·  " + (root.diskUsedBytes / 1073741824).toFixed(1) + " / " + (root.diskTotalBytes / 1073741824).toFixed(1) + " GiB"
                                    : "Disco  ·  no disponible"
                                color: "white"; font.pixelSize: 12
                                elide: Text.ElideRight
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
                        Layout.fillHeight: true
                        Layout.minimumHeight: 40
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

                // En reproducción — reproductor MPRIS real (playerctl).
                WidgetCard {
                    cardTitle: "En reproducción"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    Layout.minimumHeight: 148
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6
                        RowLayout {
                            visible: root.mprisAvailable
                            Layout.fillWidth: true
                            spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                radius: 12
                                color: "#1A1A1A"
                                border.color: "#30FFFFFF"
                                border.width: 1
                                QQC2.Label {
                                    anchors.centerIn: parent
                                    text: "♪"
                                    color: "#FF7188"
                                    font.pixelSize: 20
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: root.mediaTitle !== "" ? root.mediaTitle : "Sin reproducción activa"
                                    color: "white"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    Accessible.name: "Pista en reproducción: " + text
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: root.mediaArtist !== "" ? root.mediaArtist : "—"
                                    color: "#D7D2D6"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        QQC2.Slider {
                            id: mediaSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 1
                            enabled: root.mediaKnownDuration && root.mprisAvailable
                            onMoved: root.seekMedia(value)
                            background: Rectangle {
                                x: mediaSlider.leftPadding
                                y: mediaSlider.topPadding + mediaSlider.availableHeight / 2 - height / 2
                                width: mediaSlider.availableWidth; height: 4; radius: 2
                                color: "#3CFFFFFF"
                                Rectangle {
                                    width: mediaSlider.enabled ? mediaSlider.visualPosition * parent.width : 0
                                    height: parent.height; radius: 2; color: "#DC143C"
                                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                }
                            }
                            handle: Rectangle {
                                x: mediaSlider.leftPadding + mediaSlider.visualPosition * (mediaSlider.availableWidth - width)
                                y: mediaSlider.topPadding + mediaSlider.availableHeight / 2 - height / 2
                                width: 14; height: 14; radius: 7
                                color: "white"
                            }
                            Binding {
                                target: mediaSlider
                                property: "value"
                                value: root.mediaKnownDuration ? root.mediaPositionSeconds / root.mediaDurationSeconds : 0
                                when: !mediaSlider.pressed
                            }
                            Accessible.name: "Posición de la pista"
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            QQC2.Label {
                                text: root.formatMediaTime(root.mediaPositionSeconds)
                                color: "#AAA4AA"; font.pixelSize: 11
                                Accessible.name: "Posición actual: " + text
                            }
                            Item { Layout.fillWidth: true }
                            QQC2.Label {
                                text: root.formatMediaTime(root.mediaDurationSeconds)
                                color: "#AAA4AA"; font.pixelSize: 11
                                Accessible.name: "Duración: " + text
                            }
                        }
                        RowLayout {
                            visible: root.mprisAvailable
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 28
                            Item { Layout.fillWidth: true }
                            QQC2.ToolButton {
                                icon.name: "media-skip-backward"
                                icon.color: "white"
                                flat: true
                                Accessible.name: "Pista anterior"
                                onClicked: root.mediaPrevious()
                            }
                            QQC2.ToolButton {
                                icon.name: root.mprisPlaying ? "media-playback-pause" : "media-playback-start"
                                icon.color: "white"
                                flat: true
                                Accessible.name: root.mprisPlaying ? "Pausar" : "Reproducir"
                                onClicked: root.mediaPlayPause()
                            }
                            QQC2.ToolButton {
                                icon.name: "media-skip-forward"
                                icon.color: "white"
                                flat: true
                                Accessible.name: "Pista siguiente"
                                onClicked: root.mediaNext()
                            }
                            Item { Layout.fillWidth: true }
                        }
                        QQC2.Label {
                            visible: !root.mprisAvailable
                            Layout.fillWidth: true
                            text: "Sin reproducción activa · se activa con un reproductor MPRIS"
                            color: "#AAA4AA"
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            Accessible.name: text
                        }
                    }
                }
            }

            // --------- Columna derecha ---------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                // Calendario — navegación y selección de fechas reales.
                WidgetCard {
                    cardTitle: ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 324
                    Layout.minimumHeight: 318
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            QQC2.Label {
                                text: root.monthTitle(root.shownMonth)
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                                Layout.fillWidth: true
                                Accessible.name: "Mes mostrado: " + text
                            }
                            QQC2.ToolButton {
                                text: "Hoy"
                                Accessible.name: "Ir al día de hoy"
                                onClicked: root.showToday()
                            }
                            QQC2.ToolButton {
                                id: botonMesAnterior
                                text: "‹"
                                Accessible.name: "Mes anterior"
                                onClicked: root.shiftMonth(-1)
                                contentItem: QQC2.Label { text: botonMesAnterior.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            QQC2.ToolButton {
                                id: botonMesSiguiente
                                text: "›"
                                Accessible.name: "Mes siguiente"
                                onClicked: root.shiftMonth(1)
                                contentItem: QQC2.Label { text: botonMesSiguiente.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 7; rowSpacing: 4; columnSpacing: 4
                            Repeater {
                                model: ["D", "L", "M", "M", "J", "V", "S"]
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
                                    implicitWidth: 24; implicitHeight: 24
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
                        QQC2.Label {
                            text: "Día seleccionado · " + Qt.formatDate(root.selectedDate, "dddd d MMMM")
                                + (root.isSameDate(root.selectedDate, root.today) ? " · hoy" : "")
                            color: "#D7D2D6"; font.pixelSize: 12; font.bold: true
                            Accessible.name: text
                        }
                        QQC2.Label { text: "Información local · sin datos simulados"; color: "#AAA4AA"; font.pixelSize: 10 }
                    }
                }

                // Recordatorios — lista real del usuario, persistida localmente.
                WidgetCard {
                    cardTitle: "Recordatorios"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 108
                    headerExtra: [
                        QQC2.ToolButton {
                            flat: true
                            icon.name: "list-add"
                            icon.color: "#FF7188"
                            Accessible.name: "Añadir recordatorio nuevo"
                            onClicked: reminderInput.forceActiveFocus()
                        }
                    ]
                    ListView {
                        id: reminderList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: root.reminders
                        Accessible.name: "Lista de recordatorios"
                        delegate: QQC2.ItemDelegate {
                            id: reminderRow
                            required property int index
                            required property var modelData
                            property bool editing: false
                            hoverEnabled: true
                            width: reminderList.width
                            height: 40
                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: reminderRow.hovered || reminderRow.editing ? "#221A1E" : "transparent"
                                border.color: reminderRow.editing ? "#70DC143C" : "transparent"
                                border.width: 1
                            }
                            Rectangle {
                                id: toggler
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20; height: 20
                                radius: 10
                                color: reminderRow.modelData.d ? "#DC143C" : "transparent"
                                border.color: reminderRow.modelData.d ? "#DC143C" : "#666066"
                                border.width: 2
                                QQC2.Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    visible: reminderRow.modelData.d
                                    color: "white"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleReminder(reminderRow.index)
                                }
                                Accessible.role: Accessible.CheckBox
                                Accessible.name: "Recordatorio: " + reminderRow.modelData.t
                                Accessible.checked: reminderRow.modelData.d
                            }
                            QQC2.TextField {
                                id: textEdit
                                anchors.left: toggler.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 32
                                anchors.verticalCenter: parent.verticalCenter
                                visible: reminderRow.editing
                                text: reminderRow.modelData.t
                                font.pixelSize: 13
                                color: "white"
                                background: Rectangle { radius: 8; color: "#241B20"; border.color: "#70DC143C" }
                                onAccepted: {
                                    root.renameReminder(reminderRow.index, text)
                                    reminderRow.editing = false
                                }
                                onEditingFinished: reminderRow.editing = false
                                Keys.onEscapePressed: {
                                    reminderRow.editing = false
                                }
                            }
                            QQC2.Label {
                                anchors.left: toggler.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 32
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !reminderRow.editing
                                text: reminderRow.modelData.t
                                color: reminderRow.modelData.d ? "#8B8288" : "white"
                                font.pixelSize: 13
                                font.strikeout: reminderRow.modelData.d
                                elide: Text.ElideRight
                                Accessible.name: reminderRow.modelData.t
                                TapHandler {
                                    onDoubleTapped: {
                                        reminderRow.editing = true
                                        textEdit.forceActiveFocus()
                                        textEdit.selectAll()
                                    }
                                }
                            }
                            QQC2.ToolButton {
                                id: removeButton
                                anchors.right: parent.right
                                anchors.rightMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26; height: 26
                                visible: reminderRow.hovered
                                flat: true
                                icon.name: "list-remove"
                                icon.color: "#D7D2D6"
                                Accessible.name: "Eliminar recordatorio: " + reminderRow.modelData.t
                                onClicked: root.removeReminder(reminderRow.index)
                            }
                        }
                        QQC2.Label {
                            anchors.centerIn: parent
                            visible: root.reminders.length === 0
                            text: "Nada pendiente\nAñade un recordatorio abajo"
                            color: "#8B8288"
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            Accessible.name: "Lista de recordatorios vacía"
                        }
                        ScrollIndicator.vertical: ScrollIndicator { }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        QQC2.TextField {
                            id: reminderInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            placeholderText: "Añadir recordatorio"
                            color: "white"
                            font.pixelSize: 12
                            maximumLength: 120
                            Accessible.name: "Campo para añadir un recordatorio nuevo"
                            onAccepted: {
                                root.addReminder(text)
                                clear()
                            }
                            background: Rectangle {
                                radius: 10
                                color: "#221A1E"
                                border.color: reminderInput.activeFocus ? "#70DC143C" : "#30FFFFFF"
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 16
                            color: addTap.pressed ? "#9C0B28" : addTap.hovered ? "#FF2A54" : "#DC143C"
                            QQC2.Label {
                                anchors.centerIn: parent
                                text: "+"
                                color: "white"
                                font.pixelSize: 18
                                font.bold: true
                            }
                            MouseArea {
                                id: addTap
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: "Añadir este recordatorio"
                                onClicked: {
                                    root.addReminder(reminderInput.text)
                                    reminderInput.clear()
                                }
                            }
                        }
                    }
                }

                // Enfoque — temporizador Pomodoro real (misma lógica de 0.7.0).
                Rectangle {
                    id: pomodoroCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    radius: 16
                    color: "#D9171116"
                    border.color: root.pomodoroRunning ? "#70DC143C" : "#38FFFFFF"
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 5
                        RowLayout {
                            Layout.fillWidth: true
                            QQC2.Label {
                                text: root.pomodoroMode === "focus" ? "ENFOQUE" : "DESCANSO"
                                color: root.pomodoroMode === "focus" ? "#FF7188" : "#B9A8B0"
                                font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2
                                Layout.fillWidth: true
                            }
                            QQC2.Label {
                                text: "Ciclos · " + root.completedFocusSessions
                                color: "#AAA4AA"; font.pixelSize: 10
                                Accessible.name: "Sesiones de enfoque completadas: " + root.completedFocusSessions
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            QQC2.Label {
                                text: root.formatPomodoroTime(root.pomodoroRemainingSeconds)
                                color: "white"; font.pixelSize: 27; font.weight: Font.DemiBold
                                font.family: "monospace"
                                Accessible.name: "Tiempo restante: " + root.pomodoroRemainingSeconds + " segundos"
                            }
                            Item { Layout.fillWidth: true }
                            QQC2.Button {
                                id: pomodoroStartButton
                                Layout.preferredWidth: 112
                                Layout.preferredHeight: 34
                                text: root.pomodoroComplete
                                    ? (root.pomodoroMode === "focus" ? "Iniciar descanso" : "Iniciar enfoque")
                                    : root.pomodoroRunning ? "Pausar"
                                    : root.pomodoroStarted ? "Continuar" : "Iniciar enfoque"
                                Accessible.name: text + ". " + root.pomodoroStatus
                                onClicked: root.pomodoroRunning ? root.pausePomodoro() : root.startPomodoro()
                                contentItem: QQC2.Label {
                                    text: pomodoroStartButton.text
                                    color: "white"; font.pixelSize: 11; font.bold: true
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    radius: 17
                                    color: pomodoroStartButton.down ? "#A50F2E"
                                        : pomodoroStartButton.hovered ? "#F02A50" : "#DC143C"
                                    Behavior on color { ColorAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                }
                            }
                            QQC2.ToolButton {
                                text: "↺"
                                Accessible.name: "Reiniciar temporizador de enfoque o descanso"
                                onClicked: root.resetPomodoro()
                                contentItem: QQC2.Label {
                                    text: "↺"; color: "#D7D2D6"; font.pixelSize: 19
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 4; radius: 2; color: "#38FFFFFF"
                            Accessible.role: Accessible.ProgressBar
                            Accessible.name: "Progreso del bloque: "
                                + Math.round(100 * PomodoroClock.progress(root.pomodoroRemainingSeconds, root.pomodoroDurationSeconds)) + "%"
                            Rectangle {
                                width: parent.width * PomodoroClock.progress(root.pomodoroRemainingSeconds, root.pomodoroDurationSeconds)
                                height: parent.height; radius: 2; color: "#DC143C"
                                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            }
                        }
                        QQC2.Label {
                            text: root.pomodoroStatus
                            color: "#AAA4AA"; font.pixelSize: 10
                            Accessible.name: text
                        }
                    }
                }
            }
        }
    }
}
