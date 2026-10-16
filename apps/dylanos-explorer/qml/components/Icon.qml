import QtQuick
import QtQuick.Shapes
import DylanOS.Explorer

Item {
    id: root
    property string name
    property color color: Theme.text
    property real size: 20
    property real strokeWidth: 1.7
    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.path(root.name) }
        }
    }
}
