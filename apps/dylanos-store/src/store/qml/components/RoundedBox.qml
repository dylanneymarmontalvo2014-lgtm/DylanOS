import QtQuick
import QtQuick.Shapes
import DylanOS

// Bordered rounded surface; `glow` adds the crimson radial highlight of the React `.glow-panel`.
Item {
    id: root
    property color fill: Colors.panel
    property color border: Colors.line
    property int radius: Metrics.radiusPanel
    property bool glow: false
    property bool hero: false
    property bool dashed: false
    default property alias content: inner.data

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.hero ? "#1a0a0c" : root.fill
            strokeColor: "transparent"
            PathSvg { path: Draw.roundRect(0.5, 0.5, root.width - 1, root.height - 1, root.radius) }
            fillGradient: root.hero ? heroGrad : null
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: "transparent"
            PathSvg { path: Draw.roundRect(0.5, 0.5, root.width - 1, root.height - 1, root.radius) }
            fillGradient: (root.glow || root.hero) ? radial : null
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.border
            strokeWidth: 1
            strokeStyle: root.dashed ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: [4, 4]
            PathSvg { path: Draw.roundRect(0.5, 0.5, root.width - 1, root.height - 1, root.radius) }
        }
    }
    LinearGradient {
        id: heroGrad
        x1: 0; y1: 0; x2: root.width; y2: root.height * 0.6
        GradientStop { position: 0; color: "#1a0a0c" }
        GradientStop { position: 0.6; color: "#3a0c11" }
        GradientStop { position: 1; color: "#1a0a0c" }
    }
    RadialGradient {
        id: radial
        centerX: root.hero ? root.width * 0.85 : root.width
        centerY: root.hero ? root.height * 0.4 : 0
        focalX: centerX; focalY: centerY
        centerRadius: root.hero ? Math.max(root.width * 0.35, 180) : Math.max(root.width * 0.6, 160)
        GradientStop { position: 0; color: Colors.alpha(Colors.crimson, root.hero ? 0.45 : 0.16) }
        GradientStop { position: 1; color: Colors.alpha(Colors.crimson, 0) }
    }
    Item { id: inner; anchors.fill: parent }
}
