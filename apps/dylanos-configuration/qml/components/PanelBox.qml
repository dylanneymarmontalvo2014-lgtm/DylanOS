import QtQuick
import org.dylanos.configuration

// Panel suelto del prototipo (tarjeta con padding).
Rectangle {
    default property alias content: inner.data
    property bool pad: true

    radius: Theme.radiusCard
    color: Theme.c.surface
    border.width: 1
    border.color: Theme.c.border

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: parent.pad ? 20 : 0
    }
}
