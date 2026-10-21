import QtQuick
import org.dylanos.configuration

// Estado vacío del prototipo con borde discontinuo.
Rectangle {
    id: root
    property string icon: "search"
    property string title: ""
    property string desc: ""

    width: parent ? parent.width : 0
    height: 190
    radius: Theme.radiusCard
    color: Theme.c.surface
    border.width: 1
    border.color: Theme.c.border

    Column {
        anchors.centerIn: parent
        spacing: 8
        IconTile {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.icon
            tileColor: "#8a8183"
            size: 52
            plain: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            font.pixelSize: 16
            color: Theme.c.text
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            horizontalAlignment: Text.AlignHCenter
            text: root.desc
            font.pixelSize: 13
            color: Theme.c.textDim
            wrapMode: Text.WordWrap
        }
    }
}
