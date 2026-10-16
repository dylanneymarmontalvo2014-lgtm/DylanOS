import QtQuick
import QtQuick.Controls.Basic
import DylanOS.Explorer

ScrollBar {
    id: bar
    policy: ScrollBar.AsNeeded
    implicitWidth: 10
    contentItem: Rectangle {
        implicitWidth: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, bar.pressed ? 0.35 : 0.2)
        opacity: bar.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
    background: Item {}
}
