import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Button {
    id: root
    property string label: ""
    property color bgColor: "#302b36"
    property color textColor: "#ffffff"
    text: label
    Accessible.name: label
    Layout.fillWidth: true
    Layout.preferredHeight: 61
    hoverEnabled: true
    contentItem: Text {
        text: root.label; color: root.textColor; font.pixelSize: 23; font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: Math.min(height / 2, 24)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(root.bgColor, root.down ? 1.05 : root.hovered ? 1.5 : 1.25) }
            GradientStop { position: 1; color: root.bgColor }
        }
        border.color: root.visualFocus ? "#ffacc0" : "#30ffffff"
        border.width: root.visualFocus ? 2 : 1
        scale: root.down ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
    }
}
