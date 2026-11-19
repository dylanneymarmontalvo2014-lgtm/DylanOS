// Celda de texto de la tabla de procesos.
import QtQuick
import org.dylanos.process

Item {
    id: cell

    property string text: ""
    property bool mono: false
    property bool dim: false

    height: 34

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        text: cell.text
        color: cell.dim ? Theme.textSecondary : Theme.textPrimary
        font.family: cell.mono ? Theme.monoFont : Theme.uiFont
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
