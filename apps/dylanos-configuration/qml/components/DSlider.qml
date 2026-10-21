import QtQuick
import org.dylanos.configuration

// Deslizador del prototipo: pista 6px, relleno de acento y perilla blanca.
Item {
    id: root
    property real value: 0
    property real minimum: 0
    property real maximum: 100
    property string suffix: "%"
    signal moved(real value)

    width: 200
    height: 24

    readonly property real pct: maximum > minimum ? (value - minimum) / (maximum - minimum) : 0

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.c.track
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * root.pct
        height: 6
        radius: 3
        color: Theme.accent
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: parent.width * root.pct - width / 2
        width: 16
        height: 16
        radius: 8
        color: "#ffffff"
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => { apply(mouse) }
        onPositionChanged: (mouse) => { if (pressed) apply(mouse) }
        function apply(mouse) {
            const frac = Math.max(0, Math.min(1, mouse.x / width));
            root.moved(Math.round(root.minimum + frac * (root.maximum - root.minimum)));
        }
    }
}
