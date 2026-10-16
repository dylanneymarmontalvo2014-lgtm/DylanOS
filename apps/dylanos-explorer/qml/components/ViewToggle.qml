import QtQuick
import DylanOS.Explorer

Rectangle {
    id: root
    property int mode: 0
    signal modeSelected(int mode)

    readonly property var icons: ["grid", "list", "columns", "preview"]
    readonly property var tips: ["Cuadrícula", "Lista", "Columnas", "Vista previa"]

    width: 182; height: Theme.controlHeight
    radius: 10
    color: Theme.field
    border.width: 1; border.color: Theme.hairline

    Row {
        anchors.fill: parent
        Repeater {
            model: 4
            delegate: Rectangle {
                id: seg
                required property int index
                width: root.width / 4; height: root.height
                radius: 10
                color: root.mode === index ? Theme.accent : (m.containsMouse ? Theme.cardHover : "transparent")
                gradient: root.mode === index ? activeGrad : null
                Gradient {
                    id: activeGrad
                    GradientStop { position: 0; color: "#e8303b" }
                    GradientStop { position: 1; color: "#b3151f" }
                }
                Icon {
                    anchors.centerIn: parent
                    name: root.icons[seg.index]
                    size: 18
                    color: root.mode === seg.index ? "#fff" : Theme.textDim
                }
                MouseArea {
                    id: m
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.modeSelected(seg.index)
                }
            }
        }
    }
}
