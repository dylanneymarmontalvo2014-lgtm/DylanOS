import QtQuick
import DylanOS.Explorer

Rectangle {
    id: root
    required property var ctl
    width: 340; height: 92
    radius: 16
    color: "#241517"
    border.width: 1; border.color: Theme.border

    Txt {
        x: 18; y: 14; width: parent.width - 36
        text: root.ctl.progressText
        font.weight: Font.Medium
    }
    Rectangle {
        x: 18; y: 46; width: parent.width - 36; height: 6; radius: 3
        color: Qt.rgba(1, 1, 1, 0.12)
        clip: true
        Rectangle {
            id: fill
            visible: root.ctl.progress >= 0
            width: parent.width * Math.max(0, Math.min(1, root.ctl.progress)); height: parent.height; radius: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.accentDeep }
                GradientStop { position: 1; color: Theme.accentBright }
            }
            Behavior on width { NumberAnimation { duration: 120 } }
        }
        Rectangle {
            visible: root.ctl.progress < 0
            width: parent.width * 0.3; height: parent.height; radius: 3
            color: Theme.accent
            SequentialAnimation on x {
                running: root.visible && root.ctl.progress < 0
                loops: Animation.Infinite
                NumberAnimation { from: -100; to: 300; duration: 1100; easing.type: Easing.InOutQuad }
            }
        }
    }
    Txt {
        x: 18; y: 60; height: 22
        text: root.ctl.progress >= 0 ? Math.round(root.ctl.progress * 100) + " %" : "Trabajando…"
        color: Theme.textDim; font.pixelSize: Theme.fontSmall + 1
    }
    Txt {
        anchors { right: parent.right; rightMargin: 18; bottom: parent.bottom; bottomMargin: 10 }
        text: "Cancelar"
        color: Theme.accentLabel
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.ctl.cancelOperation() }
    }
}
