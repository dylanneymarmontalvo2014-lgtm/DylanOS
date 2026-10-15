import QtQuick
import DylanOS

// Monochrome SVG icon, recoloured by the `icon` image provider (see IconImageProvider).
Item {
    id: root
    property string name: "Box"
    property int size: 18
    property color color: "white"
    property bool spin: false
    implicitWidth: size
    implicitHeight: size
    Accessible.ignored: true

    Image {
        anchors.fill: parent
        source: root.name === "" ? "" : "image://icon/" + root.name + "/" + root.color.toString().replace("#", "")
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        smooth: true
        asynchronous: false
        RotationAnimator on rotation {
            running: root.spin && root.visible
            from: 0; to: 360; duration: 1000; loops: Animation.Infinite
        }
    }
}
