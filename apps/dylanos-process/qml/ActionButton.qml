// Botón del panel de detalle. Dos variantes: neutro y peligro (crimson).
import QtQuick
import org.dylanos.process

Rectangle {
    id: button

    property string label
    property string iconSource: ""
    property bool danger: false
    property bool solid: false
    signal clicked()

    implicitHeight: 36
    radius: Theme.controlRadius
    color: solid ? (hover.hovered ? Theme.redHover : Theme.red)
                 : danger ? (hover.hovered ? Theme.redSubtleBorder : Theme.redSubtle)
                          : (hover.hovered ? Theme.surfaceElevated : Theme.surfaceElevated)
    border.width: 1
    border.color: solid ? Theme.red
                        : danger ? Theme.redSubtleBorder : Theme.border

    Row {
        anchors.centerIn: parent
        spacing: 7

        Image {
            visible: button.iconSource.length > 0
            source: button.iconSource
            sourceSize.width: 14
            sourceSize.height: 14
            anchors.verticalCenter: parent.verticalCenter
            fillMode: Image.PreserveAspectFit
        }

        Text {
            text: button.label
            color: button.solid ? "#ffffff" : (button.danger ? Theme.redSoftText : Theme.textPrimary)
            font.family: Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: button.clicked()
    }

    Behavior on color {
        ColorAnimation { duration: 140 }
    }
}
