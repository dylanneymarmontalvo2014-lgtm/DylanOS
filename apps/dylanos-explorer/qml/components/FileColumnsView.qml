import QtQuick
import QtQuick.Controls.Basic
import DylanOS.Explorer

// Compact multi-column flow (approximation of a Miller-columns view).
GridView {
    id: view
    required property var ctl
    signal itemContext(int row, real x, real y)
    signal backgroundContext(real x, real y)

    model: ctl.model
    clip: true
    flow: GridView.FlowTopToBottom
    cellWidth: 240
    cellHeight: 36
    leftMargin: 12; topMargin: 10; bottomMargin: 10
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.horizontal: DScrollBar {}

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
            anchors { fill: parent; margins: 2 }
            radius: 9
            color: cell.selected ? Theme.selection : (area.containsMouse ? Theme.card : "transparent")
            border.width: cell.selected ? 1 : 0
            border.color: Theme.selectionBorder
        }
        FileTypeIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; size: 22; isDir: cell.isDir; suffix: cell.suffix }
        Txt { x: 44; width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter; text: cell.name }
        Icon {
            visible: cell.isDir
            x: parent.width - 24; anchors.verticalCenter: parent.verticalCenter
            name: "forward"; size: 13; color: Theme.textFaint
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
