import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Button {
    id: root
    SystemPalette { id: systemPalette; colorGroup: SystemPalette.Active }
    readonly property bool dark: systemPalette.window.hsvValue < 0.5
    property string label: ""
    property color bgColor: dark ? "#302b36" : "#e6e1e2"
    property color textColor: dark ? "#ffffff" : "#201a1b"
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
        border.color: root.visualFocus ? "#ffacc0" : (root.dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.12))
        border.width: root.visualFocus ? 2 : 1
        scale: root.down ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
    }
}
