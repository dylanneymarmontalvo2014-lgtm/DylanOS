import QtQuick
import org.dylanos.configuration

// Botón genérico del prototipo: primary, ghost y danger.
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property string variant: "ghost"
    property bool enabled2: true

    signal clicked()

    readonly property bool primary: variant === "primary"
    readonly property bool danger: variant === "danger"

    width: row.implicitWidth + (icon !== "" ? 34 : 28)
    height: 32
    radius: 16
    enabled: enabled2
    color: primary ? (mouse.pressed ? "#ad0a2a" : Theme.accent)
                   : danger ? "transparent" : Theme.c.surfaceStrong
    border.width: 1
    border.color: primary ? "transparent"
                          : danger ? Qt.rgba(Theme.accentStrong.r, Theme.accentStrong.g, Theme.accentStrong.b, 0.5)
                                   : Theme.c.border
    opacity: enabled2 ? 1.0 : 0.45

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        LucideIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            color: root.primary ? "#ffffff" : (root.danger ? Theme.accentStrong : Theme.c.text)
            size: 15
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: 14
            color: root.primary ? "#ffffff" : (root.danger ? Theme.accentStrong : Theme.c.text)
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
