import QtQuick
import org.dylanos.configuration

// Interruptor del prototipo: pista 52x30, perilla 24x24.
Rectangle {
    id: root
    property bool on: false
    signal toggled(bool value)

    width: 52
    height: 30
    radius: 15
    color: on ? Theme.accent : Theme.c.track
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: 24
        height: 24
        radius: 12
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
        x: root.on ? parent.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.on)
    }
}
