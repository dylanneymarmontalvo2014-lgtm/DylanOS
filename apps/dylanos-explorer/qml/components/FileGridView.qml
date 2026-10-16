import QtQuick
import QtQuick.Controls.Basic
import DylanOS.Explorer

GridView {
    id: view
    required property var ctl
    signal itemContext(int row, real x, real y)
    signal backgroundContext(real x, real y)

    model: ctl.model
    clip: true
    cellWidth: 132
    cellHeight: 126
    leftMargin: 14; rightMargin: 14; topMargin: 10; bottomMargin: 10
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: DScrollBar {}

    MouseArea {
        parent: view.contentItem
        z: -1
        width: Math.max(view.width, view.contentWidth)
        height: Math.max(view.height, view.contentHeight)
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => {
            view.forceActiveFocus()
            view.ctl.model.clearSelection()
            if (m.button === Qt.RightButton) {
                const p = mapToItem(null, m.x, m.y)
                view.backgroundContext(p.x, p.y)
            }
        }
    }

    delegate: Item {
        id: cell
        required property int index
        required property string name
        required property string path
        required property bool isDir
        required property string suffix
        required property bool selected
        required property bool hidden

        width: view.cellWidth; height: view.cellHeight
        opacity: hidden ? 0.55 : 1

        Rectangle {
            anchors { fill: parent; margins: 4 }
            radius: 12
            color: cell.selected ? Theme.selection : (area.containsMouse ? Theme.card : "transparent")
            border.width: cell.selected ? 1 : 0
            border.color: Theme.selectionBorder
        }
        FileTypeIcon {
            y: 16
            anchors.horizontalCenter: parent.horizontalCenter
            size: 54
            isDir: cell.isDir
            suffix: cell.suffix
        }
        Txt {
            y: 82
            x: 10; width: parent.width - 20; height: 36
            text: cell.name
            font.pixelSize: Theme.fontBase - 1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => {
                view.forceActiveFocus()
                if (m.button === Qt.RightButton) {
                    if (!cell.selected) view.ctl.model.select(cell.index, false, false)
                    const p = mapToItem(null, m.x, m.y)
                    view.itemContext(cell.index, p.x, p.y)
                } else {
                    view.ctl.model.select(cell.index, (m.modifiers & Qt.ControlModifier) !== 0, (m.modifiers & Qt.ShiftModifier) !== 0)
                }
            }
            onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) view.ctl.openItem(cell.path) }
        }
    }
}
