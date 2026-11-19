// Fila etiqueta/valor del panel de detalle.
import QtQuick
import org.dylanos.process

Item {
    id: row

    property string label
    property string value
    property bool mono: false
    property bool badge: false
    property color badgeColor: Theme.textTertiary
    // Alias legible para los tests y para cualquier consumidor que necesite el
    // valor pintado (DetailRow no es un Text, así que no tiene `text`).
    property alias text: valueText.text

    width: parent ? parent.width : 0
    implicitHeight: 26

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        color: Theme.textTertiary
        font.family: Theme.uiFont
        font.pixelSize: 12
    }

    Text {
        id: valueText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !row.badge
        width: parent.width * 0.62
        text: row.value
        color: Theme.textPrimary
        font.family: row.mono ? Theme.monoFont : Theme.uiFont
        font.pixelSize: 12
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    StateBadge {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: row.badge
        text: row.value
        dotColor: row.badgeColor
    }
}
