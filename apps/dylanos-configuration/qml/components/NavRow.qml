import QtQuick
import org.dylanos.configuration

// Fila de navegación de la barra lateral (y resultados de búsqueda).
Rectangle {
    id: root
    property string icon: "monitor"
    property color iconColor: Theme.accent
    property string title: ""
    property string sub: ""
    property bool active: false

    signal clicked()

    width: parent ? parent.width : 0
    height: 58
    radius: Theme.radiusControl
    color: mouse.containsMouse ? Theme.c.surfaceHover : "transparent"
    border.width: 1
    border.color: active ? Theme.accent : "transparent"

    Rectangle {
        visible: root.active
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.38) }
            GradientStop { position: 1.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 14
        IconTile {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            tileColor: root.iconColor
            size: 34
            plain: true
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 62
            Text {
                width: parent.width
                text: root.title
                font.pixelSize: 15
                color: Theme.c.text
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.sub
                font.pixelSize: 12
                color: Theme.c.textDim
                elide: Text.ElideRight
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
