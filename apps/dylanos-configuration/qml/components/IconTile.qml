import QtQuick
import org.dylanos.configuration

// IconTile del prototipo: mosaico con degradado o versión "plain" translúcida.
Rectangle {
    property string icon
    property color tileColor: Theme.accent
    property bool plain: false
    property int size: 44
    property real iconScale: 0.5

    width: size
    height: size
    radius: size * 0.27
    color: plain ? Qt.rgba(tileColor.r, tileColor.g, tileColor.b, 0.22) : "transparent"

    gradient: Gradient {
        GradientStop {
            position: 0.0
            color: plain ? Qt.rgba(tileColor.r, tileColor.g, tileColor.b, 0.22)
                         : Qt.lighter(tileColor, 1.25)
        }
        GradientStop {
            position: 1.0
            color: plain ? Qt.rgba(tileColor.r, tileColor.g, tileColor.b, 0.22) : tileColor
        }
    }
    border.width: plain ? 1 : 0
    border.color: Qt.rgba(tileColor.r, tileColor.g, tileColor.b, 0.3)

    LucideIcon {
        anchors.centerIn: parent
        name: parent.icon
        color: plain ? parent.tileColor : "#ffffff"
        size: parent.size * parent.iconScale
    }
}
