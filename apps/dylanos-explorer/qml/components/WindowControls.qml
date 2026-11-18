import QtQuick
import DylanOS.Explorer

Row {
    id: root
    required property var window
    spacing: 10

    Repeater {
        model: [
            { c: "#ff5f57", a: "close", n: "Cerrar" },
            { c: "#febc2e", a: "min", n: "Minimizar" },
            { c: "#28c840", a: "max", n: "Maximizar" }
        ]
        delegate: Rectangle {
            required property var modelData
            width: 14; height: 14; radius: 7
            color: mouse.containsMouse ? Qt.lighter(modelData.c, 1.18) : modelData.c
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.25)
            // Un semáforo sin nombre accesible es un control mudo: los lectores
            // de pantalla no lo anuncian y no hay forma de identificarlo.
            Accessible.name: modelData.n
            Accessible.role: Accessible.Button
            MouseArea {
                id: mouse
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
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
