import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: field
    implicitHeight: 40
    leftPadding: 13; rightPadding: 13
    color: palette.text
    selectionColor: palette.highlight
    selectedTextColor: palette.highlightedText
    placeholderTextColor: palette.placeholderText
    background: Rectangle {
        radius: 10; color: field.palette.base
        border.color: field.activeFocus ? field.palette.highlight : field.palette.mid
    }
}
