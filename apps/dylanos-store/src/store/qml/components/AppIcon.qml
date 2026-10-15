import QtQuick
import QtQuick.Shapes
import DylanOS

Item {
    id: root
    property var app
    property int size: 48
    width: size
    height: size
    Accessible.ignored: true

    readonly property color base: app ? app.color : "#444"
    readonly property color deep: Qt.rgba(base.r * 0.55, base.g * 0.55, base.b * 0.55, 1)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Colors.white(0.12)
            strokeWidth: 1
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: root.size; y2: root.size
                GradientStop { position: 0; color: root.base }
                GradientStop { position: 1; color: root.deep }
            }
            PathSvg { path: Draw.roundRect(0.5, 0.5, root.size - 1, root.size - 1, root.size * 0.22) }
        }
    }
    Image {
        id: realIcon
        visible: root.app && root.app.hasIcon
        anchors.centerIn: parent
        width: root.size * 0.62
        height: width
        source: visible ? "image://appicon/%1/%2".arg(root.app.appId).arg(root.app.iconVersion) : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
    }
    Txt {
        visible: !realIcon.visible
        anchors.centerIn: parent
        text: root.app ? root.app.glyph : ""
        color: "white"
        font.weight: Font.DemiBold
        font.pixelSize: root.size * (text.length > 1 ? 0.3 : 0.45)
    }
}
