// Gráfica de área de la pestaña Rendimiento: rejilla + relleno + línea.
//
// Se dibuja en Canvas para no añadir QtCharts. El prototipo usaba SVG con
// preserveAspectRatio:none, que equivale a escalar los puntos al área.
import QtQuick
import org.dylanos.process

Item {
    id: chart

    /// Serie 0..1 normalizada (el núcleo entrega valores ya acotados).
    property var values: []
    property color stroke: Theme.red
    property color fill: Theme.redSubtle
    property bool showGrid: true

    // Al reasignar `values` (array nuevo en cada refresco) las señales de la
    // propiedad no siempre llegan al Canvas; este contador fuerza el repintado.
    property int revision: 0

    implicitHeight: 108
    antialiasing: true

    onValuesChanged: {
        revision += 1
        canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject

        onPaint: {
            // Dependencia explícita: sin leer `revision` el Canvas no se marca
            // sucio al cambiar la serie.
            var _rev = chart.revision
            var ctx = getContext("2d")
            ctx.reset()
            var w = width
            var h = height
            if (w <= 0 || h <= 0)
                return

            if (chart.showGrid) {
                ctx.strokeStyle = "rgba(255,255,255,0.06)"
                ctx.lineWidth = 1
                for (var i = 1; i <= 3; ++i) {
                    var y = h * i / 4
                    ctx.beginPath()
                    ctx.moveTo(0, y)
                    ctx.lineTo(w, y)
                    ctx.stroke()
                }
            }

            var data = chart.values
            if (!data || data.length < 2)
                return

            var stepX = w / (data.length - 1)
            var points = []
            for (var j = 0; j < data.length; ++j) {
                var value = Math.max(0, Math.min(1, data[j]))
                points.push({ x: j * stepX, y: h - value * (h - 4) - 2 })
            }

            // Área bajo la curva.
            ctx.beginPath()
            ctx.moveTo(points[0].x, h)
            for (var k = 0; k < points.length; ++k)
                ctx.lineTo(points[k].x, points[k].y)
            ctx.lineTo(points[points.length - 1].x, h)
            ctx.closePath()
            ctx.fillStyle = chart.fill
            ctx.fill()

            // Línea superior.
            ctx.beginPath()
            ctx.moveTo(points[0].x, points[0].y)
            for (var m = 1; m < points.length; ++m)
                ctx.lineTo(points[m].x, points[m].y)
            ctx.strokeStyle = chart.stroke
            ctx.lineWidth = 1.6
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.stroke()
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
}
