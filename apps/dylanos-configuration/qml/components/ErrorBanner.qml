import QtQuick
import org.dylanos.configuration

// Banner de error del prototipo con acción de reintento.
Rectangle {
    id: root
    property string message: ""
    signal retry()

    width: parent ? parent.width : 0
    height: 54
    radius: Theme.radiusCard
    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
    border.width: 1
    border.color: Theme.accent

    Row {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        spacing: 12
        LucideIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "shield"
            color: Theme.accentStrong
            size: 18
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 200
            text: root.message
            font.pixelSize: 14
            color: Theme.c.text
            elide: Text.ElideRight
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 96
            height: 30
            radius: 15
            color: Theme.c.surfaceStrong
            border.width: 1
            border.color: Theme.c.border
            Text {
                anchors.centerIn: parent
                text: "Reintentar"
                font.pixelSize: 13
                color: Theme.c.text
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.retry()
            }
        }
    }
}
