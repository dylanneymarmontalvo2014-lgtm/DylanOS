import QtQuick
import DylanOS.Explorer

// Crimson folder with a white glyph, as in the reference cards.
Item {
    id: root
    property string glyph: ""
    property real scaleFactor: 1
    implicitWidth: 66 * scaleFactor
    implicitHeight: 56 * scaleFactor
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        x: 0; y: 0
        width: parent.width * 0.42; height: parent.height * 0.3
        radius: 6 * root.scaleFactor
        color: "#a8131d"
    }
    Rectangle {
        x: 0; y: parent.height * 0.1
        width: parent.width; height: parent.height * 0.82
        radius: 8 * root.scaleFactor
        color: "#c0141f"
    }
    Rectangle {
        x: 0; y: parent.height * 0.22
        width: parent.width; height: parent.height * 0.78
        radius: 9 * root.scaleFactor
        gradient: Gradient {
            GradientStop { position: 0; color: "#ff4d58" }
            GradientStop { position: 1; color: "#d01a26" }
        }
        Icon {
            visible: root.glyph !== ""
            anchors.centerIn: parent
            name: root.glyph
            size: 26 * root.scaleFactor
            color: "#fff"
            strokeWidth: 2
        }
    }
}
