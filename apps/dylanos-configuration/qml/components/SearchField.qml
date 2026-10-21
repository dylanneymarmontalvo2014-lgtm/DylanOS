import QtQuick
import org.dylanos.configuration

// Campo de búsqueda del prototipo.
Rectangle {
    id: root
    property string placeholder: ""
    property alias text: input.text

    signal accepted(string text)

    width: parent ? parent.width : 0
    height: 40
    radius: Theme.radiusControl
    color: Theme.c.field
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.c.border

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10
        LucideIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            color: Theme.c.textDim
            size: 16
        }
        TextInput {
            id: input
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 60
            color: Theme.c.text
            font.pixelSize: 14
            clip: true
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === "" && !input.activeFocus
                text: root.placeholder
                color: Theme.c.textDim
                font.pixelSize: 14
            }
            onAccepted: root.accepted(text)
            Keys.onEscapePressed: input.text = ""
        }
        LucideIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text !== ""
            name: "x"
            color: Theme.c.textDim
            size: 15
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: input.text = ""
            }
        }
    }
}
