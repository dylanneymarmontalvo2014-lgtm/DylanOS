// Botón de semáforo de la barra de título (ventana frameless).
//
// Se dibuja con Canvas en lugar de iconos del tema: el prototipo usa trazos de
// 1,3–1,4 px que ningún icono del pack reproduce bien a 12 px.
import QtQuick
import org.dylanos.process

Rectangle {
    id: button

    property string icon: "close"
    property bool danger: false
    signal clicked()

    width: 28
    height: 28
    radius: Theme.smallRadius
    color: hover.hovered ? (danger ? Theme.errorColor : Theme.neutralSubtle) : "transparent"

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: button.clicked()
    }

    Canvas {
        id: glyph
        anchors.centerIn: parent
        width: 12
        height: 12
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var color = (hover.hovered && button.danger) ? "#ffffff" : Theme.textSecondary
            ctx.strokeStyle = color
            ctx.lineCap = "round"
            if (button.icon === "minimize") {
                ctx.lineWidth = 1.4
                ctx.beginPath()
                ctx.moveTo(2, 6)
                ctx.lineTo(10, 6)
                ctx.stroke()
            } else if (button.icon === "maximize") {
                ctx.lineWidth = 1.3
                ctx.strokeRect(2.5, 2.5, 7, 7)
            } else {
                ctx.lineWidth = 1.4
                ctx.beginPath()
                ctx.moveTo(2.5, 2.5)
                ctx.lineTo(9.5, 9.5)
                ctx.moveTo(9.5, 2.5)
                ctx.lineTo(2.5, 9.5)
                ctx.stroke()
            }
        }
    }

    onIconChanged: glyph.requestPaint()
    Connections {
        target: hover
        function onHoveredChanged() { glyph.requestPaint() }
    }
}
