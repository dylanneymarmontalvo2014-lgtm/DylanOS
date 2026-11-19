// Cabecera de columna ordenable, con la flecha del prototipo (↑/↓).
import QtQuick
import org.dylanos.process

Item {
    id: header

    property string label
    property string roleKey

    height: 34

    readonly property bool active: processFilter.sortRole === roleKey
    readonly property string arrow: active
                                    ? (processFilter.sortDescending ? " ↓" : " ↑") : ""

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: header.label
            color: header.active ? Theme.textSecondary
                                 : (headerHover.hovered ? Theme.textSecondary : Theme.textTertiary)
            font.family: Theme.uiFont
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 0.44
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: header.arrow
            color: Theme.textSecondary
            font.family: Theme.uiFont
            font.pixelSize: 11
            font.weight: Font.Bold
        }
    }

    HoverHandler {
        id: headerHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: processFilter.toggleSort(header.roleKey)
    }
}
