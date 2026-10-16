import QtQuick
import DylanOS.Explorer

Rectangle {
    id: root
    property string name
    property string countText
    property string glyph
    signal opened()
    signal menuRequested(real x, real y)

    height: 111
    radius: Theme.radiusCard
    color: area.containsMouse ? Theme.cardHover : Theme.card
    border.width: 1
    border.color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Theme.hairline
    Behavior on color { ColorAnimation { duration: 100 } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => {
            if (m.button === Qt.RightButton) {
                const p = mapToItem(null, m.x, m.y)
                root.menuRequested(p.x, p.y)
            } else root.opened()
        }
    }

    FolderIcon {
        x: 24
        anchors.verticalCenter: parent.verticalCenter
        glyph: root.glyph
    }
    Column {
        x: 105
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 105 - 14
        spacing: 7
        Txt { width: parent.width; text: root.name; font.pixelSize: Theme.fontItem; font.weight: Font.Medium }
        Txt { width: parent.width; text: root.countText; color: Theme.textDim; font.pixelSize: Theme.fontSmall + 1 }
    }
    IconButton {
        id: more
        anchors { top: parent.top; right: parent.right; topMargin: 9; rightMargin: 12 }
        width: 26; height: 24
        icon: "more"; iconSize: 16
        iconColor: Theme.textDim
        onClicked: { const p = more.mapToItem(null, 0, height); root.menuRequested(p.x, p.y) }
    }
}
