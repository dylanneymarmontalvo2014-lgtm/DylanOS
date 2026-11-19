// DylanOS Process — Administrador de tareas.
//
// Replica visual del prototipo (ventana frameless 1320×720, barra de título,
// 4 pestañas, 4 tarjetas, tabla con detalle, rendimiento, aplicaciones y
// servicios) alimentada exclusivamente por el núcleo Rust con datos reales.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import org.dylanos.process

ApplicationWindow {
    id: root

    visible: true
    width: 1320
    height: 720
    minimumWidth: 980
    minimumHeight: 560
    title: qsTr("DylanOS Process — Administrador de tareas")
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    font.family: Theme.uiFont

    // Pestaña inicial: el prototipo abre en Procesos; la QA puede pedir otra.
    property string activeTab: initialPage && ["processes", "performance", "apps",
                                              "services"].indexOf(initialPage) >= 0
                               ? initialPage : "processes"
    property int selectedPid: -1
    property string confirmAction: ""   // "", "end", "force"
    property string toastText: ""
    property bool toastSuccess: true
    property bool priorityOpen: false
    property real toastOpacity: 0

    readonly property int sampleInterval: 1400
    readonly property int historyLength: 36
    property var cpuHistory: []
    property var memHistory: []
    property var diskHistory: []
    property var netHistory: []
    property var swapHistory: []

    // Selección por defecto: el proceso de mayor consumo, no un PID inventado.
    function selectFirstRow() {
        if (processFilter.count > 0) {
            var row = processFilter.get(0)
            selectedPid = row.pid !== undefined ? row.pid : -1
        } else {
            selectedPid = -1
        }
    }

    function selectedRow() {
        for (var i = 0; i < processFilter.count; ++i) {
            var row = processFilter.get(i)
            if (row.pid === root.selectedPid)
                return row
        }
        return null
    }

    function pushHistory(list, value) {
        var copy = list.slice()
        // Al arrancar solo hay un punto, y una serie de un punto no se puede
        // dibujar. Se rellena con ceros (no con el valor actual): así la curva
        // crece desde la línea base y se distingue la actividad real.
        if (copy.length === 0) {
            for (var i = 0; i < root.historyLength - 1; ++i)
                copy.push(0)
        }
        copy.push(value)
        while (copy.length > root.historyLength)
            copy.shift()
        return copy
    }

    function normalize(value, max) {
        if (!max || max <= 0)
            return 0
        return Math.max(0, Math.min(1, value / max))
    }

    function refreshAll() {
        processModel.refresh()
        applicationModel.reload()
        root.cpuHistory = pushHistory(cpuHistory, processModel.cpuPercent / 100)
        root.memHistory = pushHistory(memHistory, Format.ratio(processModel.memUsedBytes,
                                                              processModel.memTotalBytes))
        // Escalas de disco y red: el prototipo usaba máximo fijo por gráfica;
        // aquí se normaliza contra un techo realista de la ventana visible.
        root.diskHistory = pushHistory(diskHistory, Format.ratio(processModel.diskRead
                                                                 + processModel.diskWrite, 50e6))
        root.netHistory = pushHistory(netHistory, Format.ratio(processModel.netRx
                                                               + processModel.netTx, 10e6))
        root.swapHistory = pushHistory(swapHistory, Format.ratio(processModel.swapUsedBytes,
                                                                 processModel.swapTotalBytes))
        if (selectedPid < 0 || processModel.rowForPid(selectedPid) < 0)
            selectFirstRow()
    }

    function showToast(text, success) {
        toastText = text
        toastSuccess = success
        toastOpacity = 1
        toastTimer.restart()
    }

    function bytesText(bytes) {
        var v = Number(bytes)
        if (v < 1024)
            return v.toFixed(0) + " B"
        if (v < 1024 * 1024)
            return (v / 1024).toFixed(1) + " KB"
        if (v < 1024 * 1024 * 1024)
            return (v / (1024 * 1024)).toFixed(1) + " MB"
        return (v / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    function memText(bytes) {
        var gb = Number(bytes) / (1024 * 1024 * 1024)
        return gb >= 1 ? gb.toFixed(1) + " GB" : (Number(bytes) / 1048576).toFixed(0) + " MB"
    }

    function rateText(bytesPerSecond) {
        var v = Number(bytesPerSecond)
        if (v < 1024)
            return v.toFixed(0) + " B/s"
        if (v < 1024 * 1024)
            return (v / 1024).toFixed(1) + " KB/s"
        return (v / (1024 * 1024)).toFixed(1) + " MB/s"
    }

    // Valor sin unidad para las tarjetas, que pintan la unidad aparte.
    function memValueText(bytes) {
        var gb = Number(bytes) / (1024 * 1024 * 1024)
        return gb >= 1 ? gb.toFixed(1) : (Number(bytes) / 1048576).toFixed(0)
    }

    function percentText(value) {
        return Number(value).toFixed(1) + " %"
    }

    function durationText(seconds) {
        var s = Number(seconds)
        if (s < 60)
            return s.toFixed(0) + " s"
        var m = Math.floor(s / 60)
        if (m < 60)
            return m + " min"
        var h = Math.floor(m / 60)
        if (h < 24)
            return h + " h " + (m % 60) + " min"
        return Math.floor(h / 24) + " d " + (h % 24) + " h"
    }

    // Refresco real: cada tick lee /proc y recalcula agregados.
    Timer {
        id: sampler
        interval: root.sampleInterval
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refreshAll()
    }

    Timer {
        id: toastTimer
        interval: 2600
        onTriggered: root.toastOpacity = 0
    }

    Connections {
        target: processController
        function onNotice(text, success) { root.showToast(text, success) }
    }

    Connections {
        target: serviceModel
        function onNotice(text, success) { root.showToast(text, success) }
    }

    Component.onCompleted: {
        root.refreshAll()
        // QA opt-in: si se pasa --screenshot, se graba la ventana cuando ya hay
        // datos reales en pantalla. En uso normal la ruta está vacía.
        if (screenshotPath.length > 0)
            captureTimer.start()
    }

    // En modo captura se toman varias muestras antes de grabar para que las
    // gráficas tengan una curva real y no un único punto.
    property int warmupTicks: screenshotPath.length > 0 ? 6 : 0

    Timer {
        id: warmupTimer
        interval: root.sampleInterval
        repeat: true
        running: root.warmupTicks > 0
        onTriggered: {
            root.refreshAll()
            root.warmupTicks -= 1
        }
    }

    Timer {
        id: captureTimer
        interval: Math.max(200, screenshotDelay)
        onTriggered: {
            // Se espera al calentamiento para que el historial tenga forma.
            if (root.warmupTicks > 0) {
                restart()
                return
            }
            root.captureRequested()
        }
    }

    // La captura real la hace C++ con QQuickWindow::grabWindow(): grabToImage
    // sobre contentItem no tiene motor QML y falla con "item has no QML engine".
    signal captureRequested()

    // Ventana frameless: el fondo translúcido del prototipo se dibuja aquí.
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.windowRadius
        color: Theme.windowColor
        border.width: 1
        border.color: Theme.borderHover
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            TitleBar {
                Layout.fillWidth: true
                window: root
            }

            TabBar {
                Layout.fillWidth: true
            }

            ResourceCards {
                Layout.fillWidth: true
            }

            // Contenido de las cuatro pestañas.
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.activeTab === "processes" ? 0
                              : root.activeTab === "performance" ? 1
                              : root.activeTab === "apps" ? 2 : 3

                ProcessesPage {
                    id: processesPage
                }

                PerformancePage {}

                ApplicationsPage {}

                ServicesPage {
                    id: servicesPage
                    objectName: "servicesPage"
                }
            }

            StatusFooter {
                Layout.fillWidth: true
            }
        }

        // Toast inferior, como el prototipo.
        Rectangle {
            id: toast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 46
            width: toastLabel.implicitWidth + 36
            height: 38
            radius: 10
            color: Theme.surfaceElevated
            border.width: 1
            border.color: root.toastSuccess ? Theme.borderStrong : Theme.redSubtleBorder
            opacity: root.toastOpacity
            visible: opacity > 0

            Text {
                id: toastLabel
                anchors.centerIn: parent
                text: root.toastText
                color: root.toastSuccess ? Theme.textPrimary : Theme.redSoftText
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }
    }
}
