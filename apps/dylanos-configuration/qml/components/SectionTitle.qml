import QtQuick
import org.dylanos.configuration

// Título de sección con acción opcional a la derecha.
Item {
    id: root
    default property alias titleContent: label.data
    property string text: ""
    property alias action: actionHost.data

    width: parent ? parent.width : 0
    height: 30

    Text {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        font.pixelSize: 18
        color: Theme.c.text
    }
    Item {
        id: actionHost
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
