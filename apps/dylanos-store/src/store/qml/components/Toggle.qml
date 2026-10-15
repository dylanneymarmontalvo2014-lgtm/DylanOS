import QtQuick
import QtQuick.Controls.Basic
import DylanOS

AbstractButton {
    id: root
    checkable: true
    implicitWidth: 44
    implicitHeight: 24
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.CheckBox
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    background: Rectangle {
        radius: 12
        color: root.checked ? Colors.crimson : Colors.white(0.15)
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle { anchors.fill: parent; anchors.margins: -3; radius: 15; color: "transparent"; border.width: 2; border.color: Colors.crimsonHi; visible: root.visualFocus }
    }
    contentItem: Item {
        Rectangle {
            width: 20; height: 20; radius: 10; color: "white"; y: 2
            x: root.checked ? 22 : 2
            Behavior on x { NumberAnimation { duration: 150 } }
        }
    }
}
