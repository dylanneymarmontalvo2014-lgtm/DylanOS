import QtQuick
import DylanOS.Explorer

Rectangle {
    id: root
    property string icon
    property real iconSize: 18
    property bool active: false
    property color iconColor: Theme.textDim
    signal clicked(var mouse)
    signal rightClicked()

    implicitWidth: 34
    implicitHeight: 34
    radius: Theme.radiusControl
    color: active ? Theme.accentDeep : (area.containsMouse && enabled ? Theme.cardHover : "transparent")
    opacity: enabled ? 1 : 0.35
    Behavior on color { ColorAnimation { duration: 90 } }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        color: root.active ? "#fff" : root.iconColor
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => m.button === Qt.RightButton ? root.rightClicked() : root.clicked(m)
    }
}
