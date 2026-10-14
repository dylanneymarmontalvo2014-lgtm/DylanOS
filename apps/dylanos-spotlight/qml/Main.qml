import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: window
    width: 680
    height: 490
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Dialog
    color: "transparent"
    font.family: "Inter"

    property string currentFilter: "Todo"
    readonly property var filterOptions: ["Todo", "Apps", "Proyectos", "Archivos", "Web", "Calcular"]

    Component.onCompleted: {
        // Center on screen
        window.x = (Screen.width - window.width) / 2
        window.y = (Screen.height - window.height) / 3
        searchInput.forceActiveFocus()
    }

    Shortcut { sequence: "Escape"; onActivated: window.close() }
    Shortcut { sequence: "Ctrl+Space"; onActivated: window.close() }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 18
        color: "#f00e0d11"
        border.color: "#44DC143C"
        border.width: 1

        // Liquid glass top highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            radius: 18
            color: "#30ffffff"
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Top Header: BÚSQUEDA  ·  CTRL + ESPACIO  ·  ⚙
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "B Ú S Q U E D A"
                    color: "#8a8694"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    radius: 6
                    color: "#221f26"
                    border.color: "#30ffffff"
                    implicitWidth: shortcutText.implicitWidth + 12
                    implicitHeight: 20
                    Text {
                        id: shortcutText
                        anchors.centerIn: parent
                        text: "CTRL + ESPACIO"
                        color: "#9ca3af"
                        font.pixelSize: 9
                        font.bold: true
                    }
                }
                Text {
                    text: "⚙"
                    color: "#757180"
                    font.pixelSize: 14
                    Layout.leftMargin: 6
                }
            }

            // Search Bar Input
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: 12
                color: "#18161e"
                border.color: searchInput.activeFocus ? "#DC143C" : "#2e2b36"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: "⌕"
                        color: "#DC143C"
                        font.pixelSize: 22
                        font.bold: true
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: "¿Qué tienes en mente?"
                        placeholderTextColor: "#686472"
                        color: "#ffffff"
                        font.pixelSize: 16
                        background: null
                        selectByMouse: true
                        selectionColor: "#DC143C"
                        onTextChanged: backend.setQuery(text)

                        Keys.onDownPressed: {
                            if (resultList.count > 0) resultList.forceActiveFocus()
                        }
                        Keys.onReturnPressed: {
                            if (resultList.currentIndex >= 0) {
                                backend.activateItem(resultList.currentIndex)
                                window.close()
                            }
                        }
                    }

                    Rectangle {
                        radius: 5
                        color: "#26232d"
                        border.color: "#35ffffff"
                        implicitWidth: escText.implicitWidth + 10
                        implicitHeight: 18
                        Text {
                            id: escText
                            anchors.centerIn: parent
                            text: "esc"
                            color: "#8e8a98"
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // Filter Tabs: [Todo] [Apps] [Proyectos] [Archivos] [Web] [Calcular]
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: window.filterOptions
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        readonly property bool active: window.currentFilter === modelData

                        implicitWidth: tabLabel.implicitWidth + 16
                        implicitHeight: 28
                        radius: 14
                        color: active ? "#DC143C" : hoverArea.containsMouse ? "#201d24" : "transparent"
                        border.color: active ? "#DC143C" : "#20ffffff"

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: active ? "#ffffff" : "#9ca3af"
                            font.pixelSize: 12
                            font.weight: active ? Font.Medium : Font.Normal
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.currentFilter = modelData
                                backend.setFilter(modelData)
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // Category Subtitle
            Text {
                text: "TU ESPACIO  /  ACCESO RÁPIDO"
                color: "#686472"
                font.pixelSize: 10
                font.letterSpacing: 1.5
                font.bold: true
                Layout.topMargin: 4
            }

            // Results ListView
            ListView {
                id: resultList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: backend.results
                currentIndex: 0
                keyNavigationEnabled: true

                ScrollBar.vertical: ScrollBar {
                    active: true
                    contentItem: Rectangle { implicitWidth: 4; radius: 2; color: "#44ffffff" }
                }

                delegate: Rectangle {
                    id: itemDelegate
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: resultList.currentIndex === index

                    width: resultList.width - 6
                    height: 52
                    radius: 10
                    color: isCurrent ? "#30261923" : itemMouse.containsMouse ? "#18161f" : "transparent"
                    border.color: isCurrent ? "#77DC143C" : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 12

                        // Icon squircle: icono real de la app resuelto del tema
                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 8
                            color: "#221c25"
                            border.color: "#20ffffff"

                            Image {
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                source: "image://icons/" + modelData.icon
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                asynchronous: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: modelData.title
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.subtitle
                                color: "#9ca3af"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Right Badge
                        Rectangle {
                            radius: 6
                            color: "#1e1b24"
                            border.color: "#25ffffff"
                            implicitWidth: badgeLabel.implicitWidth + 12
                            implicitHeight: 20

                            Text {
                                id: badgeLabel
                                anchors.centerIn: parent
                                text: modelData.badge
                                color: "#a39ea9"
                                font.pixelSize: 10
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            resultList.currentIndex = index
                            backend.activateItem(index)
                            window.close()
                        }
                    }
                }

                Keys.onReturnPressed: {
                    if (currentIndex >= 0) {
                        backend.activateItem(currentIndex)
                        window.close()
                    }
                }
                Keys.onEnterPressed: {
                    if (currentIndex >= 0) {
                        backend.activateItem(currentIndex)
                        window.close()
                    }
                }
                Keys.onUpPressed: {
                    if (currentIndex > 0) currentIndex--
                    else searchInput.forceActiveFocus()
                }
                Keys.onDownPressed: {
                    if (currentIndex < count - 1) currentIndex++
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#1f1d26"
            }

            // Bottom Footer
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: backend.statsText
                    color: "#686472"
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "↵ Abrir    ↑↓ navegar"
                    color: "#8a8694"
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Acciones ^ K"
                    color: "#686472"
                    font.pixelSize: 11
                }
            }
        }
    }
}

