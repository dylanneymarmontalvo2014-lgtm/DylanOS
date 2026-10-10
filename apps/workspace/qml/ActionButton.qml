import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control
    property bool primary: false
    implicitHeight: 38
    horizontalPadding: 16
    font.pixelSize: 13
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? (control.primary ? "white" : control.palette.buttonText) : control.palette.placeholderText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: 10
        color: control.primary ? (control.down ? "#B01030" : "#DC143C") : (control.hovered ? control.palette.mid : control.palette.button)
        border.color: control.primary ? Qt.lighter("#DC143C", 1.25) : control.palette.mid
        opacity: control.enabled ? 1 : 0.5
    }
}
