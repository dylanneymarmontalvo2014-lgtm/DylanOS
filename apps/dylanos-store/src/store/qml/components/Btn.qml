import QtQuick
import QtQuick.Controls.Basic
import DylanOS

// variant: primary | ghost | quiet | danger
AbstractButton {
    id: root
    property string variant: "primary"
    property bool small: false
    property string iconName: ""
    property bool spinIcon: false
    property int minWidth: 0

    readonly property color textColor: variant === "danger" ? Colors.red400 : variant === "primary" ? "white" : Colors.fg
    implicitHeight: small ? 32 : 40
    implicitWidth: Math.max(minWidth, row.implicitWidth + (small ? 24 : 40))
    opacity: enabled ? 1 : 0.4
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.Button
    Accessible.name: text
    scale: down && variant === "primary" ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }

    background: Rectangle {
        radius: Metrics.radiusControl
        color: {
            switch (root.variant) {
            case "primary": return root.hovered && root.enabled ? Colors.crimsonHi : Colors.crimson
            case "ghost": return Colors.white(root.hovered && root.enabled ? 0.13 : 0.07)
            case "quiet": return root.hovered && root.enabled ? Colors.surfaceHover : Colors.surface2
            default: return root.hovered && root.enabled ? Colors.dangerHover : "transparent"
            }
        }
        border.width: root.variant === "primary" ? 0 : 1
        border.color: root.variant === "ghost" ? Colors.white(0.1) : root.variant === "quiet" ? Colors.line : Colors.dangerLine
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Colors.crimsonHi
            visible: root.visualFocus
        }
    }
    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Icon {
                visible: root.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: root.iconName
                size: root.small ? 14 : 16
                color: root.textColor
                spin: root.spinIcon
            }
            Txt {
                visible: root.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: root.textColor
                font.pixelSize: root.small ? 13 : 14
                font.weight: Font.Medium
            }
        }
        implicitWidth: row.implicitWidth
    }
}
