// Tarjeta pequeña del panel de detalle (CPU / RAM del proceso).
import QtQuick
import org.dylanos.process

Rectangle {
    property string label
    property string value

    implicitHeight: 58
    radius: 10
    color: Theme.surfaceElevated
    border.width: 1
    border.color: Theme.border

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        Text {
            text: parent.parent.label.toUpperCase()
            color: Theme.textTertiary
            font.family: Theme.uiFont
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: 0.42
        }

        Text {
            text: parent.parent.value
            color: Theme.textPrimary
            font.family: Theme.monoFont
            font.pixelSize: 15
            font.weight: Font.Bold
        }
    }
}
