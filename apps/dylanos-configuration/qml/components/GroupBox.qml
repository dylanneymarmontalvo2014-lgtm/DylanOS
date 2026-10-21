import QtQuick
import org.dylanos.configuration

// Grupo de filas del prototipo: tarjeta con filas separadas por línea.
Rectangle {
    id: root
    default property alias content: column.data

    radius: Theme.radiusCard
    color: Theme.c.surface
    border.width: 1
    border.color: Theme.c.border
    implicitHeight: column.implicitHeight + 2
    clip: true

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
    }
}
