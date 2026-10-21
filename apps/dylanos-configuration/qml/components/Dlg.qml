import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Diálogo modal del prototipo con overlay oscuro.
Popup {
    id: root
    property string title: ""
    default property alias content: body.data
    property alias actions: actionsHost.data

    anchors.centerIn: parent
    width: 440
    padding: 24
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        radius: 18
        color: Theme.c.menuBg
        border.width: 1
        border.color: Theme.c.border
    }
    // El overlay modal oscuro lo aporta Popup con `modal: true` (el attached
    // Overlay de QtQuick.Controls no está disponible con el import .Basic).

    contentItem: Column {
        spacing: 8
        Text {
            text: root.title
            font.pixelSize: 18
            color: Theme.c.text
        }
        Column {
            id: body
            width: parent.width
            spacing: 4
        }
        Item { width: 1; height: 16 }
        Row {
            id: actionsHost
            anchors.right: parent.right
            spacing: 10
        }
    }
}
