import QtQuick
import org.dylanos.configuration

// Controles de ventana estilo prototipo (semáforo macOS en la barra lateral).
Row {
    id: root
    // 6 px: los tres semáforos (54 px) caben en la sidebar compacta de 92 px.
    spacing: 6

    signal closeClicked()
    signal minimizeClicked()
    signal maximizeClicked()

    Repeater {
        model: [
            { color: "#ff5f57", label: "cerrar", signal: root.closeClicked },
            { color: "#febc2e", label: "minimizar", signal: root.minimizeClicked },
            { color: "#28c840", label: "maximizar", signal: root.maximizeClicked }
        ]
        delegate: Rectangle {
            required property var modelData
            width: 14
            height: 14
            radius: 7
            color: modelData.color
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.signal()
            }
        }
    }
}
