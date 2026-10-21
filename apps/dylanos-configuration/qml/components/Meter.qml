import QtQuick
import org.dylanos.configuration

// Barra de progreso del prototipo (batería, almacenamiento).
Rectangle {
    id: root
    property real pct: 0
    property color barColor: Theme.accent

    width: parent ? parent.width : 0
    height: 8
    radius: 4
    color: Theme.c.track

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.pct / 100))
        height: parent.height
        radius: 4
        color: root.barColor
        Behavior on width { NumberAnimation { duration: 300 } }
    }
}
