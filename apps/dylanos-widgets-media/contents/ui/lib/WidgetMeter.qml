import QtQuick
import "WidgetTokens.js" as Tokens

/*
 * Barra de progreso Crimson de un widget (batería, CPU, disco, memoria).
 *
 * El valor se acota a 0–1 y se dibuja con el gradiente oficial. Cuando no hay
 * dato (`value < 0`) la barra queda vacía y muestra el guion que le pasa el
 * widget: nunca se asume un 0 % que parecería una medición real.
 */
Item {
    id: meter

    property real value: -1
    property color trackColor: Qt.rgba(1, 1, 1, 0.12)

    implicitHeight: Tokens.space1 + 2

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: meter.trackColor
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        radius: height / 2
        width: meter.value < 0 ? 0
                               : Math.max(height, parent.width * Math.min(1, meter.value))
        visible: meter.value >= 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Tokens.gradientTop }
            GradientStop { position: 1; color: Tokens.gradientBottom }
        }

        Behavior on width {
            NumberAnimation { duration: Tokens.durationNormal; easing.type: Easing.OutCubic }
        }
    }
}
