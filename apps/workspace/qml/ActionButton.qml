import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control
    property bool primary: false
    implicitHeight: 40
    hoverEnabled: true
    Accessible.name: text
    horizontalPadding: 18
    font.pixelSize: 13
    font.weight: primary ? Font.DemiBold : Font.Normal

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? (control.primary ? "#ffffff" : control.palette.buttonText) : control.palette.placeholderText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 20
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: control.primary
                       ? (control.down ? "#9c0b28" : control.hovered ? "#ff2a54" : "#e81740")
                       : (control.down ? "#16131c" : control.hovered ? "#322b3a" : "#241f2b")
            }
            GradientStop {
                position: 1.0
                color: control.primary
                       ? (control.down ? "#7a051d" : control.hovered ? "#c90e33" : "#ad0a2a")
                       : (control.down ? "#0f0d14" : control.hovered ? "#221d28" : "#17141d")
            }
        }
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus
                      ? "#DC143C"
                      : control.primary
                      ? "#ff5274"
                      : control.hovered
                      ? "#48384a"
                      : "#2e2736"
        opacity: control.enabled ? 1 : 0.45

        // Specular highlight line (liquid glass)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            radius: 20
            color: control.primary ? "#50ffffff" : "#20ffffff"
        }

        scale: control.down ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }
    }
}
