// Barra de pestañas: Procesos · Rendimiento · Aplicaciones · Servicios.
import QtQuick
import org.dylanos.process

Rectangle {
    id: tabBar

    property var tabs: [
        { key: "processes", label: qsTr("Procesos") },
        { key: "performance", label: qsTr("Rendimiento") },
        { key: "apps", label: qsTr("Aplicaciones") },
        { key: "services", label: qsTr("Servicios") }
    ]

    implicitHeight: 46
    color: Theme.surfaceColor

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: tabBar.tabs

            delegate: Rectangle {
                id: tab
                required property var modelData
                readonly property bool active: root.activeTab === modelData.key

                width: tabContent.implicitWidth + 32
                height: 34
                radius: Theme.controlRadius
                color: active ? Theme.red : (tabHover.hovered ? Theme.neutralSubtle : "transparent")

                Row {
                    id: tabContent
                    anchors.centerIn: parent
                    spacing: 7

                    Canvas {
                        id: tabGlyph
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        antialiasing: true
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var color = tab.active ? "#ffffff" : (tabHover.hovered
                                                                  ? Theme.textPrimary
                                                                  : Theme.textSecondary)
                            ctx.strokeStyle = color
                            ctx.fillStyle = color
                            ctx.lineWidth = 1.6
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            if (tab.modelData.key === "processes") {
                                // Pulso: línea que sube y baja.
                                ctx.beginPath()
                                ctx.moveTo(2, 10)
                                ctx.lineTo(5, 10)
                                ctx.lineTo(7, 4)
                                ctx.lineTo(10, 16)
                                ctx.lineTo(12, 10)
                                ctx.lineTo(18, 10)
                                ctx.stroke()
                            } else if (tab.modelData.key === "performance") {
                                // Barras.
                                ctx.beginPath()
                                ctx.moveTo(4, 16); ctx.lineTo(4, 9)
                                ctx.moveTo(10, 16); ctx.lineTo(10, 4)
                                ctx.moveTo(16, 16); ctx.lineTo(16, 12)
                                ctx.stroke()
                            } else if (tab.modelData.key === "apps") {
                                // Cuadrícula.
                                ctx.beginPath()
                                for (var i = 0; i < 2; ++i)
                                    for (var j = 0; j < 2; ++j)
                                        ctx.strokeRect(3 + i * 8, 3 + j * 8, 6, 6)
                            } else {
                                // Engranaje simplificado: círculo + radios.
                                ctx.beginPath()
                                ctx.arc(10, 10, 3, 0, Math.PI * 2)
                                ctx.stroke()
                                ctx.beginPath()
                                ctx.moveTo(10, 2); ctx.lineTo(10, 4.2)
                                ctx.moveTo(10, 15.8); ctx.lineTo(10, 18)
                                ctx.moveTo(18, 10); ctx.lineTo(15.8, 10)
                                ctx.moveTo(4.2, 10); ctx.lineTo(2, 10)
                                ctx.stroke()
                            }
                        }
                    }

                    Text {
                        text: tab.modelData.label
                        color: tab.active ? "#ffffff" : (tabHover.hovered
                                                         ? Theme.textPrimary : Theme.textSecondary)
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler {
                    id: tabHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.activeTab = tab.modelData.key
                }
            }
        }
    }
}
