import QtQuick
import DylanOS.Explorer

// variant: "primary" | "secondary" | "danger" | "outline"
Rectangle {
    id: root
    property string text
    property string icon
    property string variant: "secondary"
    signal clicked()

    readonly property bool filled: variant === "primary" || variant === "danger"
    implicitHeight: 34
    implicitWidth: row.implicitWidth + 28
    radius: Theme.radiusSmall + 1
    opacity: enabled ? 1 : 0.4
    border.width: filled ? 0 : 1
    border.color: variant === "outline" ? Theme.accentDeep : Theme.border
    gradient: Gradient {
        GradientStop { position: 0; color: root.variant === "primary" ? (area.pressed ? Theme.accentDeep : Theme.accent)
                       : root.variant === "danger" ? (area.pressed ? "#9c1c25" : "#d1303b")
                       : (area.containsMouse ? Theme.cardHover : Theme.card) }
        GradientStop { position: 1; color: root.variant === "primary" ? Theme.accentDeep
                       : root.variant === "danger" ? "#a8212b"
                       : (area.containsMouse ? Theme.cardHover : Theme.card) }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: 16
            color: root.variant === "outline" ? Theme.accentLabel : Theme.text
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.variant === "outline" ? Theme.accentLabel : Theme.text
            font.weight: Font.Medium
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
