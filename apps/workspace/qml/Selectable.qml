import QtQuick
import QtQuick.Controls.Basic

ItemDelegate {
    id: row
    background: Rectangle {
        radius: 9
        color: row.highlighted ? row.palette.highlight : row.hovered ? row.palette.button : "transparent"
        opacity: row.highlighted ? 0.3 : 1
        border.color: row.highlighted ? row.palette.highlight : "transparent"
    }
}
