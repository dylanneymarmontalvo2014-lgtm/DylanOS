// Pestaña Procesos: búsqueda, filtros, tabla ordenable y panel de detalle.
//
// Todo sale de processFilter (datos reales de /proc); las acciones se envían a
// processController, que habla con el kernel. El diálogo de confirmación es
// obligatorio antes de enviar cualquier señal.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import org.dylanos.process

Item {
    id: page

    // Selección compartida con la ventana. No puede ser `property alias` de la
    // ventana padre (la página se instancia antes de tener ese contexto), así
    // que se sincroniza en los dos sentidos con un handler y una Connections.
    property int selectedPid: root.selectedPid

    // Fila de detalle derivada de la selección real.
    property var detail: null
    property bool confirming: false
    property string confirmKind: ""
    property bool priorityOpen: false

    readonly property var chips: [
        { key: "all", label: qsTr("Todos") },
        { key: "Ejecutando", label: qsTr("Activos") },
        { key: "Suspendido", label: qsTr("En pausa") },
        { key: "Espera de E/S", label: qsTr("Espera de E/S") },
        { key: "Zombi", label: qsTr("Zombis") }
    ]
    readonly property var priorities: [qsTr("Baja"), qsTr("Normal"), qsTr("Alta"),
                                      qsTr("Tiempo real")]

    function refreshDetail() {
        var found = null
        for (var i = 0; i < processFilter.count; ++i) {
            var row = processFilter.get(i)
            if (row.pid === page.selectedPid) {
                found = row
                break
            }
        }
        detail = found
    }

    onSelectedPidChanged: {
        confirming = false
        priorityOpen = false
        if (root.selectedPid !== selectedPid)
            root.selectedPid = selectedPid
        refreshDetail()
    }

    Connections {
        target: root
        function onSelectedPidChanged() {
            if (page.selectedPid !== root.selectedPid)
                page.selectedPid = root.selectedPid
        }
    }

    Connections {
        target: processFilter
        function onCountChanged() { page.refreshDetail() }
        function onRowsInserted() { page.refreshDetail() }
        function onRowsRemoved() { page.refreshDetail() }
        function onModelReset() { page.refreshDetail() }
    }

    Timer {
        interval: root.sampleInterval
        running: true
        repeat: true
        onTriggered: page.refreshDetail()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Barra de búsqueda y filtros ──────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 57

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.border
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    // Caja de búsqueda (flex 0 0 220px en el prototipo).
                    Rectangle {
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 34
                        radius: Theme.controlRadius
                        color: Theme.surfaceElevated
                        border.width: 1
                        border.color: searchInput.activeFocus ? Theme.redSubtleBorder : Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 8
                            spacing: 8

                            Canvas {
                                Layout.preferredWidth: 15
                                Layout.preferredHeight: 15
                                antialiasing: true
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.strokeStyle = Theme.textTertiary
                                    ctx.lineWidth = 1.5
                                    ctx.lineCap = "round"
                                    ctx.beginPath()
                                    ctx.arc(6.4, 6.4, 4.1, 0, Math.PI * 2)
                                    ctx.stroke()
                                    ctx.beginPath()
                                    ctx.moveTo(9.8, 9.8)
                                    ctx.lineTo(13.2, 13.2)
                                    ctx.stroke()
                                }
                            }

                            TextField {
                                id: searchInput
                                Layout.fillWidth: true
                                placeholderText: qsTr("Buscar procesos…")
                                color: Theme.textPrimary
                                placeholderTextColor: Theme.textTertiary
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                                selectByMouse: true
                                background: null
                                topPadding: 0
                                bottomPadding: 0
                                leftPadding: 0
                                rightPadding: 0
                                onTextChanged: processFilter.searchText = text
                                Component.onCompleted: text = processFilter.searchText
                            }

                            // Botón de limpiar, solo con texto.
                            Item {
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                visible: searchInput.text.length > 0

                                Canvas {
                                    anchors.fill: parent
                                    antialiasing: true
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        ctx.strokeStyle = Theme.textTertiary
                                        ctx.lineWidth = 1.6
                                        ctx.lineCap = "round"
                                        ctx.beginPath()
                                        ctx.moveTo(2, 2); ctx.lineTo(12, 12)
                                        ctx.moveTo(12, 2); ctx.lineTo(2, 12)
                                        ctx.stroke()
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInput.text = ""
                                        processFilter.searchText = ""
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: page.chips

                        delegate: FilterChip {
                            required property var modelData
                            label: modelData.label
                            selected: processFilter.stateFilter === modelData.key
                            onClicked: processFilter.stateFilter = modelData.key
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: qsTr("%1 procesos").arg(processFilter.count)
                        color: Theme.textTertiary
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                }
            }

            // ── Tabla ────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Column {
                    anchors.fill: parent

                    // Cabecera fija.
                    Rectangle {
                        width: parent.width
                        height: 34
                        color: Theme.surfaceColor

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 12

                            HeaderCell {
                                width: parent.width * 0.30
                                label: qsTr("PROCESO")
                                roleKey: "name"
                            }
                            HeaderCell {
                                width: parent.width * 0.11
                                label: qsTr("PID")
                                roleKey: "pid"
                            }
                            HeaderCell {
                                width: parent.width * 0.13
                                label: qsTr("CPU")
                                roleKey: "cpu"
                            }
                            HeaderCell {
                                width: parent.width * 0.16
                                label: qsTr("MEMORIA")
                                roleKey: "mem"
                            }
                            HeaderCell {
                                width: parent.width * 0.17
                                label: qsTr("ESTADO")
                                roleKey: "status"
                            }
                            HeaderCell {
                                width: parent.width * 0.13
                                label: qsTr("USUARIO")
                                roleKey: "user"
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Theme.border
                        }
                    }

                    ListView {
                        id: table
                        objectName: "processTable"
                        width: parent.width
                        height: parent.height - 34
                        clip: true
                        model: processFilter
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            active: true
                        }
                        cacheBuffer: 400

                        delegate: Rectangle {
                            id: rowItem
                            required property int index
                            required property int pid
                            required property string name
                            required property string command
                            required property string user
                            required property real cpu
                            required property real rss
                            required property string icon
                            required property string iconPath
                            required property string state
                            required property int threads

                            readonly property bool selected: pid === page.selectedPid

                            width: table.width
                            height: 34
                            color: selected ? Theme.redSubtle
                                            : (rowHover.hovered ? "#0affffff" : "transparent")

                            HoverHandler {
                                id: rowHover
                            }

                            TapHandler {
                                onTapped: page.selectedPid = rowItem.pid
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: Theme.borderSubtle
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 12

                                // Proceso: icono real + nombre.
                                Item {
                                    width: parent.width * 0.30
                                    height: parent.height

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 9

                                        ProcessIcon {
                                            width: 24
                                            height: 24
                                            iconName: rowItem.icon
                                            iconPath: rowItem.iconPath
                                            fallbackText: rowItem.name.charAt(0).toUpperCase()
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: rowItem.name
                                            color: Theme.textPrimary
                                            font.family: Theme.uiFont
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                            width: Math.min(implicitWidth, parent.parent.width - 34)
                                        }
                                    }
                                }

                                TableCell {
                                    width: parent.width * 0.11
                                    text: rowItem.pid.toFixed(0)
                                    mono: true
                                    dim: true
                                }
                                TableCell {
                                    width: parent.width * 0.13
                                    text: Format.percent(rowItem.cpu)
                                    mono: true
                                }
                                TableCell {
                                    width: parent.width * 0.16
                                    text: Format.bytes(rowItem.rss)
                                    mono: true
                                }

                                Item {
                                    width: parent.width * 0.17
                                    height: parent.height

                                    StateBadge {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: rowItem.state
                                        dotColor: Theme.stateColor(rowItem.state)
                                    }
                                }

                                TableCell {
                                    width: parent.width * 0.13
                                    text: rowItem.user
                                    dim: true
                                }
                            }
                        }

                        // Sin resultados: mensaje claro, nunca una tabla vacía muda.
                        Text {
                            anchors.centerIn: parent
                            visible: processFilter.count === 0
                            text: processFilter.searchText.length > 0
                                  ? qsTr("No se encontraron procesos que coincidan con la búsqueda.")
                                  : qsTr("No hay procesos que coincidan con el filtro.")
                            color: Theme.textTertiary
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }

        // ── Panel de detalle ─────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 296
            Layout.fillHeight: true
            color: Theme.surfaceColor

            Rectangle {
                anchors.left: parent.left
                width: 1
                height: parent.height
                color: Theme.border
            }

            ScrollView {
                anchors.fill: parent
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Item {
                    width: parent.width
                    implicitHeight: detailColumn.implicitHeight + 36

                    Column {
                        id: detailColumn
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 18
                        width: parent.width - 36
                        spacing: 16

                        // Encabezado con icono real y ruta.
                        Row {
                            width: parent.width
                            spacing: 12
                            visible: page.detail !== null

                            ProcessIcon {
                                width: 44
                                height: 44
                                iconName: page.detail ? page.detail.icon : ""
                                iconPath: page.detail ? page.detail.iconPath : ""
                                fallbackText: page.detail
                                              ? page.detail.name.charAt(0).toUpperCase() : ""
                            }

                            Column {
                                width: parent.width - 56
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: page.detail ? page.detail.name : ""
                                    color: Theme.textPrimary
                                    font.family: Theme.uiFont
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: page.detail && page.detail.command.length > 0
                                          ? page.detail.command : qsTr("—")
                                    color: Theme.textTertiary
                                    font.family: Theme.monoFont
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                        }

                        // Dos tarjetas: CPU y RAM del proceso.
                        Grid {
                            width: parent.width
                            columns: 2
                            columnSpacing: 10
                            visible: page.detail !== null

                            DetailStat {
                                width: (detailColumn.width - 10) / 2
                                label: qsTr("CPU")
                                value: page.detail ? Format.percent(page.detail.cpu) : "—"
                            }
                            DetailStat {
                                width: (detailColumn.width - 10) / 2
                                label: qsTr("RAM")
                                value: page.detail ? Format.bytes(page.detail.rss) : "—"
                            }
                        }

                        // Datos reales del proceso.
                        Column {
                            width: parent.width
                            spacing: 10
                            visible: page.detail !== null

                            DetailRow {
                                objectName: "detailPid"
                                label: qsTr("PID")
                                value: page.detail ? page.detail.pid.toFixed(0) : "—"
                                mono: true
                            }
                            DetailRow {
                                label: qsTr("Usuario")
                                value: page.detail ? page.detail.user : "—"
                            }
                            DetailRow {
                                label: qsTr("Estado")
                                value: page.detail ? page.detail.state : "—"
                                badge: true
                                badgeColor: page.detail ? Theme.stateColor(page.detail.state)
                                                        : Theme.textTertiary
                            }
                            DetailRow {
                                label: qsTr("Hilos")
                                value: page.detail ? page.detail.threads.toFixed(0) : "—"
                                mono: true
                            }
                            DetailRow {
                                label: qsTr("Tiempo activo")
                                value: page.detail ? Format.duration(page.detail.uptime) : "—"
                                mono: true
                            }
                            DetailRow {
                                label: qsTr("E/S de disco")
                                value: page.detail
                                       ? (Format.bytes(page.detail.ioRead) + " · "
                                          + Format.bytes(page.detail.ioWrite))
                                       : "—"
                                mono: true
                            }

                            // Prioridad real: abre el selector, nunca un dato falso.
                            Item {
                                width: parent.width
                                height: 26

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Prioridad")
                                    color: Theme.textTertiary
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                }

                                Rectangle {
                                    id: priorityTrigger
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: priorityRow.implicitWidth + 20
                                    height: 26
                                    radius: Theme.smallRadius
                                    color: priorityHover.hovered ? Theme.surfaceElevated
                                                                 : Theme.surfaceElevated
                                    border.width: 1
                                    border.color: priorityHover.hovered ? Theme.borderStrong
                                                                       : Theme.border

                                    Row {
                                        id: priorityRow
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            id: priorityLabel
                                            text: page.detail
                                                  ? page.priorities[processController.priorityLevel(
                                                                        page.detail.nice)]
                                                  : qsTr("—")
                                            color: Theme.textPrimary
                                            font.family: Theme.uiFont
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        Canvas {
                                            width: 10
                                            height: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            rotation: page.priorityOpen ? 180 : 0
                                            antialiasing: true
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.reset()
                                                ctx.strokeStyle = Theme.textTertiary
                                                ctx.lineWidth = 1.4
                                                ctx.beginPath()
                                                ctx.moveTo(1, 1)
                                                ctx.lineTo(5, 5)
                                                ctx.lineTo(9, 1)
                                                ctx.stroke()
                                            }

                                            Behavior on rotation {
                                                NumberAnimation { duration: 150 }
                                            }
                                        }
                                    }

                                    HoverHandler {
                                        id: priorityHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        onTapped: page.priorityOpen = !page.priorityOpen
                                    }
                                }
                            }
                        }

                        // Menú de prioridad: aplica el cambio real.
                        Rectangle {
                            width: parent.width
                            visible: page.priorityOpen
                            implicitHeight: priorityOptions.implicitHeight + 10
                            radius: 11
                            color: Theme.surfaceElevated
                            border.width: 1
                            border.color: Theme.borderStrong

                            Column {
                                id: priorityOptions
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 2

                                Repeater {
                                    model: page.priorities

                                    delegate: Rectangle {
                                        required property int index
                                        required property string modelData

                                        width: parent.width
                                        height: 30
                                        radius: Theme.smallRadius
                                        color: optHover.hovered ? "#12ffffff" : "transparent"

                                        readonly property bool current: page.detail
                                                                        && processController.priorityLevel(
                                                                            page.detail.nice) === index

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: parent.modelData
                                            color: Theme.textPrimary
                                            font.family: Theme.uiFont
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: parent.current
                                            text: "✓"
                                            color: Theme.textPrimary
                                            font.pixelSize: 12
                                        }

                                        HoverHandler {
                                            id: optHover
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        TapHandler {
                                            onTapped: {
                                                page.priorityOpen = false
                                                if (page.detail)
                                                    processController.setPriority(page.detail.pid,
                                                                                  parent.index)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Confirmación en línea: nunca se mata sin confirmar.
                        Rectangle {
                            width: parent.width
                            visible: page.confirming
                            implicitHeight: confirmColumn.implicitHeight + 26
                            radius: 11
                            color: Theme.redSubtle
                            border.width: 1
                            border.color: Theme.redSubtleBorder

                            Column {
                                id: confirmColumn
                                anchors.fill: parent
                                anchors.margins: 13
                                spacing: 10

                                Text {
                                    width: parent.width
                                    text: page.confirmKind === "force"
                                          ? qsTr("¿Forzar la finalización de %1? Los cambios sin guardar se perderán.").arg(
                                                page.detail ? page.detail.name : "")
                                          : qsTr("¿Enviar SIGTERM a %1 para que se cierre?").arg(
                                                page.detail ? page.detail.name : "")
                                    color: Theme.textPrimary
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.45
                                }

                                Row {
                                    spacing: 8

                                    ActionButton {
                                        width: (confirmColumn.width - 8) / 2
                                        implicitHeight: 30
                                        label: qsTr("Cancelar")
                                        onClicked: page.confirming = false
                                    }

                                    ActionButton {
                                        width: (confirmColumn.width - 8) / 2
                                        implicitHeight: 30
                                        label: qsTr("Confirmar")
                                        danger: false
                                        solid: true
                                        onClicked: {
                                            page.confirming = false
                                            if (!page.detail)
                                                return
                                            if (page.confirmKind === "force")
                                                processController.forceTerminateProcess(
                                                            page.detail.pid)
                                            else
                                                processController.terminateProcess(page.detail.pid)
                                        }
                                    }
                                }
                            }
                        }

                        // Acciones reales.
                        Column {
                            width: parent.width
                            spacing: 8
                            visible: page.detail !== null

                            ActionButton {
                                width: parent.width
                                label: qsTr("Finalizar proceso")
                                danger: true
                                onClicked: {
                                    page.confirmKind = "end"
                                    page.confirming = true
                                }
                            }

                            ActionButton {
                                width: parent.width
                                label: qsTr("Forzar finalización")
                                solid: true
                                onClicked: {
                                    page.confirmKind = "force"
                                    page.confirming = true
                                }
                            }
                        }

                        // Sin selección.
                        Text {
                            width: parent.width
                            visible: page.detail === null
                            text: qsTr("Selecciona un proceso en la lista para ver su información detallada y gestionar sus acciones.")
                            color: Theme.textTertiary
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 22
                            lineHeight: 1.5
                        }
                    }
                }
            }
        }
    }
}
