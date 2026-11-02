import QtQuick
import org.dylanos.configuration

// Interruptor del prototipo: pista 52x30, perilla 24x24.
Rectangle {
    id: root
    property bool on: false
    signal toggled(bool value)
    readonly property int motionDuration: CrimsonGlass.effectiveEffects.animations
                                          ? Math.min(180, CrimsonGlass.settings.animationDuration)
                                          : 0

    width: 52
    height: 30
    radius: 15
    color: on ? Theme.accent : Theme.c.track
    border.width: 1
    border.color: on ? Theme.glassBorder : Theme.c.border
    Behavior on color { ColorAnimation { duration: root.motionDuration } }
    Behavior on border.color { ColorAnimation { duration: root.motionDuration } }

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 2 }
        height: 1
        radius: 1
        color: Theme.glassSpecular
        opacity: root.on ? 0.32 : 0.12
    }

    Rectangle {
        width: 24
        height: 24
        radius: 12
        color: "#ffffff"
        border.width: 1
        border.color: Theme.glassSpecular
        anchors.verticalCenter: parent.verticalCenter
        x: root.on ? parent.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.on)
    }
}
