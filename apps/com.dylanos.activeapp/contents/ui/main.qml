pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import "ActiveAppLogic.js" as ActiveAppLogic

PlasmoidItem {
    id: root

    property string activeAppName: "DylanOS"
    property int activeIndex: -1
    property bool hasActiveTask: false
    property bool canMinimize: false
    property bool canMaximize: false
    property bool canClose: false
    property bool isMaximized: false
    property bool isKeepAbove: false
    property real requestedWidth: 192

    TaskManager.TasksModel {
        id: tasksModel
        filterByScreen: false
        filterByVirtualDesktop: false
        filterNotMinimized: false
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    Connections {
        target: tasksModel
        function onDataChanged() { root.updateActiveApp() }
        function onRowsInserted() { root.updateActiveApp() }
        function onRowsRemoved() { root.updateActiveApp() }
        function onModelReset() { root.updateActiveApp() }
        function onCountChanged() { root.updateActiveApp() }
    }

    Component.onCompleted: root.updateActiveApp()

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumWidth: 192
    Layout.maximumWidth: 4096
    Layout.preferredWidth: Math.min(Math.max(root.requestedWidth, 192), 4096)

    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {
        id: container
        implicitWidth: Math.max(192, contentRow.implicitWidth + 24)
        implicitHeight: parent ? parent.height : 30
        clip: true
        onImplicitWidthChanged: root.requestedWidth = implicitWidth
        Component.onCompleted: root.requestedWidth = implicitWidth

        RowLayout {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Text {
                id: titleLabel
                text: root.activeAppName
                font.bold: true
                font.pixelSize: 13
                font.family: "Inter"
                color: "#ffffff"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            // Botones de acciones disponibles en el dock superior para TODAS las aplicaciones
            RowLayout {
                id: actionButtons
                spacing: 6
                visible: root.hasActiveTask

                // Separador vertical sutil entre título y acciones
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    color: "#33FFFFFF"
                    Layout.alignment: Qt.AlignVCenter
                }

                // Nueva instancia real del lanzador asociado. En Firefox,
                // VS Code y el resto de apps multi-ventana abre otra ventana.
                QQC2.ToolButton {
                    id: newWindowButton
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: "Abrir una ventana nueva"
                    onClicked: root.actionNewInstance()

                    background: Rectangle {
                        radius: 6
                        color: newWindowButton.down ? "#9c0b28" : newWindowButton.hovered ? "#2A2A2E" : "transparent"
                        border.color: newWindowButton.hovered || newWindowButton.activeFocus ? "#ff5274" : "transparent"
                        border.width: 1
                    }

                    contentItem: Text {
                        text: "+"
                        color: newWindowButton.hovered ? "#FFFFFF" : "#B3B3B3"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Botón de menú desplegable de Acciones
                QQC2.ToolButton {
                    id: actionsMenuBtn
                    Layout.preferredWidth: actionsMenuRow.implicitWidth + 12
                    Layout.preferredHeight: 22
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: "Abrir acciones de ventana"
                    onClicked: actionsMenu.open()

                    background: Rectangle {
                        radius: 4
                        color: actionsMenuBtn.down ? "#9c0b28" : actionsMenuBtn.hovered ? "#2A2A2E" : "#1A1A1E"
                        border.color: actionsMenuBtn.hovered || actionsMenuBtn.activeFocus ? "#ff5274" : "#2E2736"
                        border.width: 1
                    }

                    contentItem: RowLayout {
                        id: actionsMenuRow
                        spacing: 4

                        Text {
                            text: "Acciones"
                            color: actionsMenuBtn.hovered ? "#ffffff" : "#D0D0D0"
                            font.pixelSize: 11
                            font.family: "Inter"
                            horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            text: "▾"
                            color: "#B3B3B3"
                            font.pixelSize: 10
                        }
                    }

                    QQC2.Menu {
                        id: actionsMenu
                        y: parent.height + 4

                        QQC2.MenuItem {
                            text: "Minimizar"
                            enabled: root.canMinimize
                            onTriggered: root.actionMinimize()
                        }
                        QQC2.MenuItem {
                            text: root.isMaximized ? "Restaurar tamaño" : "Maximizar"
                            enabled: root.canMaximize
                            onTriggered: root.actionMaximize()
                        }
                        QQC2.MenuItem {
                            text: root.isKeepAbove ? "Desactivar siempre visible" : "Mantener siempre encima"
                            onTriggered: root.actionKeepAbove()
                        }
                        QQC2.MenuSeparator {}
                        QQC2.MenuItem {
                            text: "Cerrar ventana"
                            enabled: root.canClose
                            onTriggered: root.actionClose()
                        }
                    }
                }

                // Botón directo: Minimizar
                QQC2.ToolButton {
                    id: minimizeButton
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    focusPolicy: Qt.StrongFocus
                    enabled: root.canMinimize
                    opacity: root.canMinimize ? 1 : 0.38
                    Accessible.name: "Minimizar ventana"
                    onClicked: root.actionMinimize()

                    background: Rectangle {
                        radius: 4
                        color: minimizeButton.down ? "#30FFFFFF" : minimizeButton.hovered ? "#2A2A2E" : "transparent"
                        border.color: minimizeButton.hovered || minimizeButton.activeFocus ? "#40FFFFFF" : "transparent"
                        border.width: 1
                    }

                    contentItem: Text {
                        text: "—"
                        color: minimizeButton.hovered ? "#FFFFFF" : "#B3B3B3"
                        font.pixelSize: 11
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Botón directo: Maximizar / Restaurar
                QQC2.ToolButton {
                    id: maximizeButton
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    focusPolicy: Qt.StrongFocus
                    enabled: root.canMaximize
                    opacity: root.canMaximize ? 1 : 0.38
                    Accessible.name: "Maximizar o restaurar ventana"
                    onClicked: root.actionMaximize()

                    background: Rectangle {
                        radius: 4
                        color: maximizeButton.down ? "#30FFFFFF" : maximizeButton.hovered ? "#2A2A2E" : "transparent"
                        border.color: maximizeButton.hovered || maximizeButton.activeFocus ? "#40FFFFFF" : "transparent"
                        border.width: 1
                    }

                    contentItem: Text {
                        text: root.isMaximized ? "❐" : "□"
                        color: maximizeButton.hovered ? "#FFFFFF" : "#B3B3B3"
                        font.pixelSize: root.isMaximized ? 11 : 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Mantener encima es una acción KWin real y reversible.
                QQC2.ToolButton {
                    id: keepAboveButton
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: "Mantener ventana encima"
                    onClicked: root.actionKeepAbove()

                    background: Rectangle {
                        radius: 6
                        color: keepAboveButton.down ? "#9c0b28"
                            : root.isKeepAbove ? "#5ADC143C"
                            : keepAboveButton.hovered ? "#2A2A2E" : "transparent"
                        border.color: root.isKeepAbove ? "#ff5274"
                            : keepAboveButton.hovered || keepAboveButton.activeFocus ? "#40FFFFFF" : "transparent"
                        border.width: 1
                    }

                    contentItem: Text {
                        text: "⌃"
                        color: root.isKeepAbove || keepAboveButton.hovered ? "#FFFFFF" : "#B3B3B3"
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Botón directo: Cerrar (con acento Crimson al pasar el cursor)
                QQC2.ToolButton {
                    id: closeButton
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    focusPolicy: Qt.StrongFocus
                    enabled: root.canClose
                    opacity: root.canClose ? 1 : 0.38
                    Accessible.name: "Cerrar ventana"
                    onClicked: root.actionClose()

                    background: Rectangle {
                        radius: 4
                        color: closeButton.down ? "#9c0b28" : closeButton.hovered ? "#DC143C" : "transparent"
                        border.color: closeButton.hovered || closeButton.activeFocus ? "#ff5274" : "transparent"
                        border.width: 1
                    }

                    contentItem: Text {
                        text: "✕"
                        color: closeButton.hovered ? "#FFFFFF" : "#B3B3B3"
                        font.pixelSize: 11
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    function resolveAppName(idx) {
        var appName = ActiveAppLogic.humanName(tasksModel.data(idx, TaskManager.AbstractTasksModel.AppName))
        if (appName) return appName

        var genericName = ActiveAppLogic.humanName(tasksModel.data(idx, TaskManager.AbstractTasksModel.GenericName))
        if (genericName) return genericName

        var appId = ActiveAppLogic.nameFromId(tasksModel.data(idx, TaskManager.AbstractTasksModel.AppId))
        if (appId) return appId

        var display = ActiveAppLogic.nameFromDisplay(tasksModel.data(idx, Qt.DisplayRole))
        if (display) return display

        return "Aplicación"
    }

    function updateActiveApp() {
        var found = false
        for (var i = 0; i < tasksModel.count; ++i) {
            var idx = tasksModel.makeModelIndex(i)
            if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive) === true) {
                root.activeIndex = i
                root.hasActiveTask = true
                root.activeAppName = resolveAppName(idx)
                root.canMinimize = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimizable) === true
                root.canMaximize = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMaximizable) === true
                root.canClose = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsClosable) === true
                root.isMaximized = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMaximized) === true
                root.isKeepAbove = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsKeepAbove) === true
                found = true
                break
            }
        }
        if (!found) {
            root.activeIndex = -1
            root.hasActiveTask = false
            root.activeAppName = "DylanOS"
            root.canMinimize = false
            root.canMaximize = false
            root.canClose = false
            root.isMaximized = false
            root.isKeepAbove = false
        }
    }

    function actionMinimize() {
        if (root.activeIndex >= 0) {
            tasksModel.requestToggleMinimized(tasksModel.makeModelIndex(root.activeIndex))
        }
    }

    function actionNewInstance() {
        if (root.activeIndex >= 0) {
            tasksModel.requestNewInstance(tasksModel.makeModelIndex(root.activeIndex))
        }
    }

    function actionMaximize() {
        if (root.activeIndex >= 0) {
            tasksModel.requestToggleMaximized(tasksModel.makeModelIndex(root.activeIndex))
        }
    }

    function actionClose() {
        if (root.activeIndex >= 0) {
            tasksModel.requestClose(tasksModel.makeModelIndex(root.activeIndex))
        }
    }

    function actionKeepAbove() {
        if (root.activeIndex >= 0) {
            tasksModel.requestToggleKeepAbove(tasksModel.makeModelIndex(root.activeIndex))
        }
    }
}
