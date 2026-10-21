import QtQuick
import org.dylanos.configuration

// Aviso flotante inferior (equivalente al toast del prototipo).
Rectangle {
    id: root
    property string message: ""
    property int visibleMs: 2600

    function show(text) {
        message = text
        visible = true
        timer.restart()
    }

    width: messageText.implicitWidth + 40
    height: 40
    radius: 20
    color: Qt.rgba(0.055, 0.039, 0.039, 0.95)
    border.width: 1
    border.color: Theme.c.border
    visible: false
    z: 100

    Text {
        id: messageText
        anchors.centerIn: parent
        text: root.message
        font.pixelSize: 13
        color: "#ffffff"
    }
    Timer {
        id: timer
        interval: root.visibleMs
        onTriggered: root.visible = false
    }
    Behavior on opacity { NumberAnimation { duration: 180 } }
}
