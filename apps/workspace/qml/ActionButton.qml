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
                       ? (control.down ? Qt.darker(control.palette.highlight, 1.25)
                          : control.hovered ? Qt.lighter(control.palette.highlight, 1.18) : control.palette.highlight)
                       : (control.down ? Qt.darker(control.palette.button, 1.15)
                          : control.hovered ? Qt.lighter(control.palette.button, 1.18) : control.palette.button)
            }
            GradientStop {
                position: 1.0
                color: control.primary
                       ? (control.down ? Qt.darker(control.palette.highlight, 1.45)
                          : control.hovered ? Qt.darker(control.palette.highlight, 1.08) : Qt.darker(control.palette.highlight, 1.2))
                       : (control.down ? Qt.darker(control.palette.button, 1.3)
                          : control.hovered ? Qt.lighter(control.palette.button, 1.05) : Qt.darker(control.palette.button, 1.12))
            }
        }
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus
                      ? "#DC143C"
                      : control.primary
                      ? Qt.lighter(control.palette.highlight, 1.3)
                      : control.hovered
                      ? Qt.lighter(control.palette.mid, 1.25)
                      : control.palette.mid
        opacity: control.enabled ? 1 : 0.45

        // Specular highlight line (liquid glass)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            radius: 20
            color: control.primary ? "#50ffffff" : "#18ffffff"
        }

        scale: control.down ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }
    }
}
