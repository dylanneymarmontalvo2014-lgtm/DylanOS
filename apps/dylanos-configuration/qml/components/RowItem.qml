import QtQuick
import org.dylanos.configuration

// Fila del prototipo: icono opcional, título/desc y contenido a la derecha.
Rectangle {
    id: root
    property string icon: ""
    property color iconColor: Theme.accent
    property string title: ""
    property string desc: ""
    property bool last: false
    default property alias content: contentHost.data

    width: parent ? parent.width : 0
    height: Math.max(64, contentHost.childrenRect.height + 28)
    color: mouse.containsMouse && root.enabled ? Theme.c.surfaceHover : "transparent"

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 16

        IconTile {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            icon: root.icon
            tileColor: root.iconColor
            size: 36
            plain: true
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 160
            height: childrenRect.height
            Text {
                width: parent.width
                text: root.title
                font.pixelSize: 15
                color: Theme.c.text
                elide: Text.ElideRight
            }
            Text {
                anchors.top: parent.top
                anchors.topMargin: 20
                width: parent.width
                visible: root.desc !== ""
                text: root.desc
                font.pixelSize: 13
                color: Theme.c.textDim
                elide: Text.ElideRight
            }
        }
        Item {
            id: contentHost
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            // Altura fija de banda de control (40px, la del prototipo): los
            // hijos se anclan a este Item con verticalCenter y, si la altura
            // dependiera de childrenRect, y↔altura formaría un bucle de
            // bindings. Con altura estable childrenRect solo mide anchos.
            height: 40
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        visible: !root.last
        color: Theme.c.border
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: false
    }
}
