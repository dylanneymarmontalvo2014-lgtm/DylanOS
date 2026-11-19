// Tarjeta de recurso de la cabecera (CPU, RAM, Swap, Procesos).
//
// Replica el prototipo: icono en cuadro tenue, etiqueta, valor monoespaciado y
// una gráfica o barra de progreso opcional.
import QtQuick
import QtQuick.Layouts
import org.dylanos.process

Rectangle {
    id: card

    property string label
    property string value
    property string suffix
    property string iconSource
    property color accent: Theme.red
    property color accentSubtle: Theme.redSubtle
    /// 0..1; si se pasa, se dibuja barra de progreso en vez de gráfica.
    property real progress: -1
    property color progressColor: Theme.info
    /// Puntos "x,y x,y" para la minigráfica (92x30).
    property string points: ""
    property string footer: ""

    // Altura derivada del contenido: con una altura fija la barra de progreso y
    // el pie quedaban recortados (la RAM no mostraba su barra).
    implicitHeight: content.implicitHeight + 26
    // El contenedor fija la altura de la fila; las cuatro tarjetas la comparten.
    height: implicitHeight
    radius: Theme.cardRadius
    color: Theme.surfaceElevated
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 13
        spacing: 10

        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            Rectangle {
                width: 28
                height: 28
                radius: 8
                color: card.accentSubtle

                Image {
                    anchors.centerIn: parent
                    source: card.iconSource
                    sourceSize.width: 15
                    sourceSize.height: 15
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            Text {
                text: card.label
                color: Theme.textSecondary
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Layout.alignment: Qt.AlignVCenter | Qt.AlignBottom

            Text {
                text: card.value
                color: Theme.textPrimary
                font.family: Theme.monoFont
                font.pixelSize: 21
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignBottom
            }

            Text {
                visible: card.suffix.length > 0
                text: card.suffix
                color: Theme.textTertiary
                font.family: Theme.monoFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 2
            }

            Item { Layout.fillWidth: true }

            // Minigráfica del prototipo (solo CPU).
            Canvas {
                id: spark
                visible: card.points.length > 0 && card.progress < 0
                Layout.preferredWidth: 92
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignBottom
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    if (!card.points.length)
                        return
                    var pts = card.points.trim().split(" ")
                    if (pts.length < 2)
                        return
                    ctx.beginPath()
                    ctx.strokeStyle = card.accent
                    ctx.lineWidth = 2
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    for (var i = 0; i < pts.length; ++i) {
                        var pair = pts[i].split(",")
                        var x = parseFloat(pair[0]) / 100 * width
                        var y = parseFloat(pair[1]) / 36 * height
                        if (i === 0)
                            ctx.moveTo(x, y)
                        else
                            ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: card
                    function onPointsChanged() { spark.requestPaint() }
                }
            }
        }

        // Barra de progreso (RAM, Swap).
        Rectangle {
            visible: card.progress >= 0
            Layout.fillWidth: true
            Layout.preferredHeight: 5
            radius: 999
            color: Theme.trackColor

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, card.progress))
                height: parent.height
                radius: 999
                color: card.progressColor
                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            visible: card.footer.length > 0
            text: card.footer
            color: Theme.textTertiary
            font.family: Theme.uiFont
            font.pixelSize: 11
            Layout.fillWidth: true
        }
    }
}
