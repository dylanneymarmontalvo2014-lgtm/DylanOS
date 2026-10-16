import QtQuick
import DylanOS.Explorer

Row {
    id: root
    required property var window
    spacing: 10

    Repeater {
        model: [
            { c: "#ff5f57", a: "close" },
            { c: "#febc2e", a: "min" },
            { c: "#28c840", a: "max" }
        ]
        delegate: Rectangle {
            required property var modelData
            width: 14; height: 14; radius: 7
            color: modelData.c
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.25)
            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData.a === "close") root.window.close()
                    else if (modelData.a === "min") root.window.showMinimized()
                    else if (root.window.visibility === Window.Maximized) root.window.showNormal()
                    else root.window.showMaximized()
                }
            }
        }
    }
}
