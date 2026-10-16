import QtQuick
import DylanOS.Explorer

Rectangle {
    id: root
    property string text
    property string icon
    property bool active: false
    signal clicked()
    signal rightClicked()

    height: 34
    radius: 10
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: root.active ? "#8c1a21" : (area.containsMouse ? Theme.cardHover : "transparent") }
        GradientStop { position: 1; color: root.active ? "#6a1218" : (area.containsMouse ? Theme.cardHover : "transparent") }
    }

    Icon {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 19
        color: root.active ? "#fff" : Theme.textDim
    }
    Txt {
        x: 42
        width: parent.width - 52
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        font.pixelSize: Theme.fontItem - 1
        font.weight: root.active ? Font.Medium : Font.Normal
        color: root.active ? "#fff" : Theme.text
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => m.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
