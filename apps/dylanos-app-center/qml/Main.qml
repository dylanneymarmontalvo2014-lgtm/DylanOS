import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: window
    visible: true
    title: "App Center · DylanOS"
    flags: Qt.FramelessWindowHint
    color: "#0a080c"
    visibility: Window.FullScreen
    font.family: "Inter"

    readonly property color accent: "#DC143C"
    // Cuadrícula adaptable: en ventanas pequeñas caben menos columnas y filas,
    // así que cada página muestra menos aplicaciones y el resto se desplaza.
    readonly property int columns: width >= 1600 ? 8 : (width >= 1200 ? 6 : 4)
    readonly property int rows: height >= 820 ? 3 : 2
    readonly property int rowHeight: 146
    readonly property int pageSize: columns * rows
    property int currentPage: 0
    property int totalPages: 1
    property var pageItems: []
    property int pendingIndex: -1

    function reload() {
        totalPages = Math.max(1, appModel.pageCount(pageSize))
        currentPage = Math.min(currentPage, totalPages - 1)
        pageItems = appModel.itemsForPage(currentPage, pageSize)
        var next = pendingIndex
        pendingIndex = -1
        var desired = next >= 0 ? next : 0
        grid.currentIndex = pageItems.length ? Math.max(0, Math.min(desired, pageItems.length - 1)) : -1
    }

    function goToPage(page, targetIndex) {
        if (page < 0 || page >= totalPages) return
        currentPage = page
        pendingIndex = (targetIndex === undefined || targetIndex < 0) ? -1 : targetIndex
        reload()
        reveal.restart()
    }

    function applySearch(text) {
        appModel.setFilter(text)
        currentPage = 0
        reload()
    }

    // Mantiene visible la celda enfocada al navegar con el teclado. En pantallas
    // pequeñas la cuadrícula no cabe y sin esto el foco se salía de la vista al
    // usar las flechas o AvPág/RePág. Qt.callLater espera a que GridView cree el
    // delegado antes de medir su posición.
    function revealCell(index) {
        if (index < 0) return
        Qt.callLater(function() {
            var item = grid.itemAtIndex(index)
            if (!item) return
            var top = item.mapToItem(scroller.contentItem, 0, 0).y
            var bottom = top + item.height
            var margin = 20
            var maxY = Math.max(0, scroller.contentHeight - scroller.height)
            if (top < scroller.contentY + margin)
                scroller.contentY = Math.max(0, top - margin)
            else if (bottom > scroller.contentY + scroller.height - margin)
                scroller.contentY = Math.min(maxY, bottom - scroller.height + margin)
        })
    }

    Component.onCompleted: {
        reload()
        searchField.forceActiveFocus()
    }

    Connections {
        target: appModel
        function onModelReset() { window.reload() }
        function onLaunchSucceeded() { window.close() }
        function onLaunchFailed(message) { errorLabel.text = message; errorPopup.open() }
    }

    Shortcut { sequence: "Escape"; onActivated: window.close() }
    Shortcut { sequence: "Ctrl+F"; onActivated: { searchField.forceActiveFocus(); searchField.selectAll() } }
    // Las flechas las maneja el GridView (celda a celda y cambio de página en
    // los bordes); un Shortcut de ventana se comería esas teclas antes de que
    // la cuadrícula pudiera navegar.

    // Dark crimson smoke background matching Image 1
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#0d090d" }
            GradientStop { position: 0.35; color: "#220912" }
            GradientStop { position: 0.65; color: "#14050a" }
            GradientStop { position: 1.0; color: "#080608" }
        }

        // Click outside closes
        MouseArea {
            anchors.fill: parent
            onClicked: window.close()
        }
    }

    // El contenido completo vive dentro de un Flickable: cuando la ventana es
    // más baja que la cuadrícula (pantallas pequeñas), la página se desplaza
    // con la rueda, el trackpad, el teclado o la barra lateral en lugar de
    // recortarse. `contentHeight` cubre al menos la altura visible, de modo que
    // la paginación sigue anclada abajo cuando todo cabe.
    Flickable {
        id: scroller
        anchors.fill: parent
        anchors.topMargin: 24
        anchors.bottomMargin: 110 // Leave space for bottom floating dock
        anchors.leftMargin: Math.max(32, (window.width - 1280) / 2)
        anchors.rightMargin: Math.max(32, (window.width - 1280) / 2)
        contentWidth: width
        contentHeight: Math.max(height, mainLayout.implicitHeight)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: verticalBar
            policy: ScrollBar.AsNeeded
            width: 10

            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: verticalBar.pressed ? window.accent : "#8c2038"
            }

            background: Rectangle {
                implicitWidth: 6
                radius: 3
                color: "#1f1016"
            }
        }

        ColumnLayout {
            id: mainLayout
            width: scroller.width
            height: scroller.contentHeight
            spacing: 16

            // Top Search Bar (Image 1 style: centered pill with red outline)
            Rectangle {
                id: searchBarContainer
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 380
                implicitHeight: 42
                radius: 21
                color: "#d01c0f16"
                border.color: searchField.activeFocus ? "#DC143C" : "#722533"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 14
                    spacing: 8

                    Text {
                        text: "⌕"
                        color: "#DC143C"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: ""
                        color: "white"
                        font.pixelSize: 14
                        background: null
                        selectByMouse: true
                        selectionColor: accent
                        onTextChanged: applySearch(text)
                        onAccepted: { if (pageItems.length > 0) appModel.launchApp(pageItems[0].desktopId) }
                        Keys.onDownPressed: grid.forceActiveFocus()
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Cuadrícula de aplicaciones (columnas x filas según la ventana).
            GridView {
                id: grid
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(mainLayout.width, 1280)
                Layout.preferredHeight: window.rows * window.rowHeight
                cellWidth: width / window.columns
                cellHeight: window.rowHeight
                model: pageItems
                interactive: false
                keyNavigationEnabled: true
                clip: false
                // Al mover la selección con el teclado, desplaza la vista para
                // que el elemento enfocado nunca quede fuera de pantalla.
                onCurrentIndexChanged: window.revealCell(currentIndex)

                delegate: ItemDelegate {
                    id: tile
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    onClicked: {
                        grid.forceActiveFocus()
                        grid.currentIndex = index
                        appModel.launchApp(modelData.desktopId)
                    }
                    Accessible.name: modelData.name

                    background: Rectangle {
                        radius: 16
                        color: tile.hovered || (grid.activeFocus && grid.currentIndex === tile.index) ? "#28ffffff" : "transparent"
                        border.color: grid.activeFocus && grid.currentIndex === tile.index ? "#DC143C" : "transparent"
                    }

                    contentItem: ColumnLayout {
                        spacing: 8
                        anchors.centerIn: parent

                        // Icon Container (squircle style)
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 68
                            Layout.preferredHeight: 68

                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: "#18141d"
                                opacity: 0.3
                            }

                            Image {
                                anchors.fill: parent
                                source: "image://icon/" + modelData.icon
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                            }
                        }

                        // App Label
                        Label {
                            text: modelData.name
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            Layout.preferredWidth: grid.cellWidth - 12
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                Keys.onReturnPressed: { if (currentIndex >= 0 && currentIndex < pageItems.length) appModel.launchApp(pageItems[currentIndex].desktopId) }
                Keys.onEnterPressed: { if (currentIndex >= 0 && currentIndex < pageItems.length) appModel.launchApp(pageItems[currentIndex].desktopId) }
                // Izquierda/derecha mueven la selección celda a celda; en los
                // bordes cambian de página conservando la fila actual.
                Keys.onLeftPressed: {
                    if (currentIndex < 0) return
                    var row = Math.floor(currentIndex / columns)
                    if (currentIndex % columns === 0)
                        goToPage(currentPage - 1, row * columns + columns - 1)
                    else
                        currentIndex--
                }
                Keys.onRightPressed: {
                    if (currentIndex < 0) {
                        goToPage(currentPage + 1, 0)
                        return
                    }
                    var row = Math.floor(currentIndex / columns)
                    if (currentIndex % columns === columns - 1 || currentIndex === pageItems.length - 1)
                        goToPage(currentPage + 1, row * columns)
                    else
                        currentIndex++
                }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_PageDown) {
                        event.accepted = true
                        goToPage(currentPage + 1, grid.currentIndex)
                    } else if (event.key === Qt.Key_PageUp) {
                        event.accepted = true
                        goToPage(currentPage - 1, grid.currentIndex)
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: pageItems.length === 0
                    text: "No se encontraron aplicaciones coincidentes."
                    color: "#d3c8d5"
                    font.pixelSize: 16
                }
            }

            Item { Layout.fillHeight: true }

            // Pagination Dots (. . . • . .) exactly as in Image 1
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Repeater {
                    model: Math.max(1, window.totalPages)
                    delegate: Rectangle {
                        required property int index
                        readonly property bool isCurrent: index === window.currentPage

                        width: isCurrent ? 18 : 6
                        height: 6
                        radius: 3
                        color: isCurrent ? "#DC143C" : "#55202c"

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 180 } }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.goToPage(index)
                        }
                    }
                }
            }
        }
    }

    NumberAnimation { id: reveal; target: grid; property: "opacity"; from: 0.3; to: 1; duration: 150 }

    Popup {
        id: errorPopup
        anchors.centerIn: parent
        width: Math.min(480, window.width - 60)
        padding: 24
        background: Rectangle { color: "#29222d"; radius: 20; border.color: "#eb607e" }
        contentItem: Label { id: errorLabel; color: "white"; wrapMode: Text.Wrap }
    }
}
