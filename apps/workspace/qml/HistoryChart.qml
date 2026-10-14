import QtQuick

Canvas {
    id: chart
    property var samples: []
    property color lineColor: "#DC143C"
    property color gridColor: "#243c3b44"
    onSamplesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = gridColor
        ctx.lineWidth = 1
        for (let i = 1; i <= 3; i++) {
            ctx.beginPath(); ctx.moveTo(0, height * i / 4); ctx.lineTo(width, height * i / 4); ctx.stroke()
        }
        if (samples.length < 2) return
        const step = width / 59
        const start = width - step * (samples.length - 1)
        ctx.beginPath()
        for (let j = 0; j < samples.length; j++) {
            const y = height - Math.max(0, Math.min(100, samples[j])) * height / 100
            if (j === 0) ctx.moveTo(start, y); else ctx.lineTo(start + j * step, y)
        }
        ctx.strokeStyle = lineColor; ctx.lineWidth = 2; ctx.stroke()
        ctx.lineTo(width, height); ctx.lineTo(start, height); ctx.closePath()
        ctx.fillStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.12); ctx.fill()
    }
}
