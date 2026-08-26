import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: window

    visible: true
    flags: Qt.FramelessWindowHint
    color: "#e60a0a0a"
    visibility: Window.FullScreen

    readonly property color accent: "#e11d2a"
    readonly property int pageSize: 10

    property int currentPage: 0
    property int pendingPage: 0

    readonly property int totalPages:
    Math.max(1, appModel.pageCount(pageSize))

    property var pageItems:
    appModel.itemsForPage(currentPage, pageSize)

    function goToPage(page) {
        if (page < 0 || page >= totalPages || page === currentPage)
            return

            pendingPage = page
            pageAnim.start()
    }

    function applySearch(text) {
        appModel.setFilter(text)
        currentPage = 0
        pageItems = appModel.itemsForPage(0, pageSize)
    }

    Keys.onEscapePressed: Qt.quit()
    Keys.onLeftPressed: goToPage(currentPage - 1)
    Keys.onRightPressed: goToPage(currentPage + 1)

    MouseArea {
        anchors.fill: parent

        property real startX: 0
        property bool dragging: false

        onPressed: (mouse) => {
            startX = mouse.x
            dragging = false
        }

        onPositionChanged: (mouse) => {
            if (Math.abs(mouse.x - startX) > 10)
                dragging = true
        }

        onReleased: (mouse) => {
            const delta = mouse.x - startX

            if (Math.abs(delta) > 80) {
                delta > 0
                ? goToPage(currentPage - 1)
                : goToPage(currentPage + 1)
            }
            else if (!dragging) {
                Qt.quit()
            }
        }
    }

    Item {
        id: root

        anchors.fill: parent
        opacity: 0
        scale: 0.92

        Component.onCompleted: {
            opacity = 1
            scale = 1
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 40
            spacing: 24

            TextField {
                id: searchField

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 420
                Layout.preferredHeight: 44

                placeholderText: "Buscar aplicaciones..."

                color: "white"
                font.pixelSize: 15

                horizontalAlignment:
                TextInput.AlignHCenter

                background: Rectangle {
                    radius: 12

                    color: "#1a1a1a"

                    border.width:
                    searchField.activeFocus ? 2 : 1

                    border.color:
                    searchField.activeFocus
                    ? accent
                    : "#333333"
                }

                onTextChanged:
                applySearch(text)
            }

            Item {
                Layout.fillHeight: true
            }

            GridView {
                id: grid

                Layout.alignment: Qt.AlignHCenter

                Layout.preferredWidth: 5 * 170
                Layout.preferredHeight: 2 * 170

                cellWidth: 170
                cellHeight: 170

                interactive: false

                model: pageItems

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            Layout.alignment:
                            Qt.AlignHCenter

                            width: 88
                            height: 88

                            radius: 22

                            color:
                            iconMouse.containsMouse
                            ? "#2a1414"
                            : "transparent"

                            border.width:
                            iconMouse.containsMouse ? 2 : 0

                            border.color: accent

                            Image {
                                id: appIcon

                                anchors.centerIn: parent

                                width: 72
                                height: 72

                                /*
                                 * modelData.icon contiene el nombre
                                 * del icono proporcionado por KService.
                                 *
                                 * Ejemplo:
                                 * firefox
                                 * dolphin
                                 * vlc
                                 * org.kde.kate
                                 */

                                source:
                                "image://icon/" + modelData.icon

                                fillMode:
                                Image.PreserveAspectFit

                                asynchronous: true
                                cache: true

                                smooth: true

                                /*
                                 * Evita que un icono inexistente
                                 * genere una imagen rota.
                                 */
                                onStatusChanged: {
                                    if (status === Image.Error) {
                                        console.log(
                                            "No se pudo cargar el icono:",
                                            modelData.icon
                                        )
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.alignment:
                            Qt.AlignHCenter

                            Layout.preferredWidth: 140

                            text: modelData.name

                            color: "white"

                            font.pixelSize: 13

                            horizontalAlignment:
                            Text.AlignHCenter

                            wrapMode:
                            Text.WordWrap

                            elide:
                            Text.ElideRight

                            maximumLineCount: 2
                        }
                    }

                    MouseArea {
                        id: iconMouse

                        anchors.fill: parent

                        hoverEnabled: true

                        onClicked: {
                            appModel.launchApp(
                                modelData.globalIndex
                            )

                            Qt.quit()
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.alignment:
                Qt.AlignHCenter

                spacing: 16

                Button {
                    text: "‹"

                    enabled: currentPage > 0

                    onClicked:
                    goToPage(currentPage - 1)
                }

                Row {
                    spacing: 8

                    Repeater {
                        model: totalPages

                        delegate: Rectangle {
                            width: 8
                            height: 8

                            radius: 4

                            color:
                            index === currentPage
                            ? accent
                            : "#555555"

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6

                                onClicked:
                                goToPage(index)
                            }
                        }
                    }
                }

                Button {
                    text: "›"

                    enabled:
                    currentPage < totalPages - 1

                    onClicked:
                    goToPage(currentPage + 1)
                }
            }

            Item {
                Layout.preferredHeight: 20
            }
        }
    }

    SequentialAnimation {
        id: pageAnim

        NumberAnimation {
            target: grid
            property: "opacity"

            to: 0

            duration: 120
        }

        ScriptAction {
            script: {
                currentPage = pendingPage

                pageItems =
                appModel.itemsForPage(
                    currentPage,
                    pageSize
                )
            }
        }

        NumberAnimation {
            target: grid
            property: "opacity"

            to: 1

            duration: 150
        }
    }
}
