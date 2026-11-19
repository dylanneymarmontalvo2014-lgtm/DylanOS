// Chip de filtro (Todos / Activos / En pausa / Sin responder / Zombis).
import QtQuick
import org.dylanos.process

Rectangle {
    id: chip

    property string label
    property bool selected: false
    property color borderColor: selected ? Theme.redSubtleBorder : Theme.border
    signal clicked()

    implicitWidth: labelText.implicitWidth + 26
    implicitHeight: 29
    radius: 999
    color: selected ? Theme.redSubtle : Theme.surfaceElevated
    border.width: 1
    border.color: borderColor

    Text {
        id: labelText
        anchors.centerIn: parent
        text: chip.label
        color: chip.selected ? Theme.redSoftText : Theme.textSecondary
        font.family: Theme.uiFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (chip.selected)
                return
            chip.borderColor = hovered ? Theme.borderStrong : Theme.border
        }
    }

    TapHandler {
        onTapped: chip.clicked()
    }

    onSelectedChanged: borderColor = selected ? Theme.redSubtleBorder : Theme.border

    Behavior on color {
        ColorAnimation { duration: 140 }
    }
}
