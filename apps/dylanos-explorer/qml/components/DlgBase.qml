import QtQuick
import QtQuick.Controls.Basic
import DylanOS.Explorer

Popup {
    id: root
    property string title
    property string icon: "info"
    property color tint: Theme.accentLabel
    default property alias body: bodyCol.data
    property alias footer: footerRow.data

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: 0
    width: 440
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 140; easing.type: Easing.OutCubic }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 90 } }

    background: Rectangle {
        radius: 18
        border.width: 1
        border.color: Theme.border
        gradient: Gradient {
            GradientStop { position: 0; color: "#221315" }
            GradientStop { position: 1; color: "#150b0d" }
        }
    }

    contentItem: Column {
        Item {
            width: parent.width; height: 68
            Rectangle {
                x: 24; anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36; radius: 18
                color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.16)
                Icon { anchors.centerIn: parent; name: root.icon; size: 19; color: root.tint }
            }
            Txt {
                x: 74; width: parent.width - 74 - 24
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                font.pixelSize: Theme.fontSection
                font.weight: Font.Medium
            }
        }
        Item {
            width: parent.width
            height: bodyCol.implicitHeight + 6
            Column { id: bodyCol; x: 24; width: parent.width - 48; spacing: 10 }
        }
        Item {
            width: parent.width; height: 74
            Row {
                id: footerRow
                anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                spacing: 10
            }
        }
    }
}
