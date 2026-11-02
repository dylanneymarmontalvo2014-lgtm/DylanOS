import QtQuick
import org.dylanos.configuration

// Deslizador del prototipo: pista 6px, relleno de acento y perilla blanca.
Item {
    id: root
    property real value: 0
    property real minimum: 0
    property real maximum: 100
    property string suffix: "%"
    signal moved(real value)
    readonly property int motionDuration: CrimsonGlass.effectiveEffects.animations
                                          ? Math.min(180, CrimsonGlass.settings.animationDuration)
                                          : 0

    width: 200
    height: 24

    readonly property real pct: maximum > minimum ? (value - minimum) / (maximum - minimum) : 0

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.c.track
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * root.pct
        height: 6
        radius: 3
        color: Theme.accent
        Behavior on width { NumberAnimation { duration: mouse.pressed ? 0 : root.motionDuration; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: (parent.width - width) * root.pct
        width: 16
        height: 16
        radius: 8
        color: "#ffffff"
        border.width: 1
        border.color: Theme.glassBorder
        Behavior on x { NumberAnimation { duration: mouse.pressed ? 0 : root.motionDuration; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 3 }
            height: 1
            color: Theme.glassSpecular
            opacity: 0.75
        }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => { apply(mouse) }
        onPositionChanged: (mouse) => { if (pressed) apply(mouse) }
        function apply(mouse) {
            const frac = Math.max(0, Math.min(1, mouse.x / width));
            root.moved(Math.round(root.minimum + frac * (root.maximum - root.minimum)));
        }
    }
}
