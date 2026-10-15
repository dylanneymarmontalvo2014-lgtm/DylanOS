import QtQuick
import QtQuick.Controls.Basic
import DylanOS

Item {
    id: root
    property real value: 0
    property bool indeterminate: false
    property string label: ""
    implicitHeight: 6
    implicitWidth: 200
    Accessible.role: Accessible.ProgressBar
    Accessible.name: label

    Rectangle { anchors.fill: parent; radius: 3; color: Colors.white(0.1) }
    Item {
        anchors.fill: parent
        clip: true
        Rectangle {
            visible: !root.indeterminate
            height: parent.height
            width: parent.width * Math.max(0, Math.min(100, root.value)) / 100
            radius: 3
            color: Colors.crimson
            Behavior on width { NumberAnimation { duration: 300 } }
        }
        Rectangle {
            id: bar
            visible: root.indeterminate
            height: parent.height
            width: parent.width * 0.4
            radius: 3
            color: Colors.crimson
            SequentialAnimation on x {
                running: root.indeterminate && root.visible
                loops: Animation.Infinite
                NumberAnimation { from: -bar.width; to: root.width * 1.0; duration: 1200; easing.type: Easing.InOutQuad }
            }
        }
    }
}
