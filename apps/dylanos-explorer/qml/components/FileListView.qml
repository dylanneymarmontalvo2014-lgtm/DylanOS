import QtQuick
import QtQuick.Controls.Basic
import DylanOS.Explorer

Item {
    id: root
    required property var ctl
    signal itemContext(int row, real x, real y)
    signal backgroundContext(real x, real y)

    readonly property real colDate: Math.max(180, width * 0.27)
    readonly property real colSize: Math.max(90, width * 0.10)
    readonly property real colKind: Math.max(110, width * 0.14)
    readonly property real xDate: width - colDate - colSize - colKind - 20
    readonly property real xSize: width - colSize - colKind - 20
    readonly property real xKind: width - colKind - 20

    function sortBy(key) {
        const m = root.ctl.model
        if (m.sortKey === key) m.sortAscending = !m.sortAscending
        else { m.sortKey = key; m.sortAscending = true }
    }

    Rectangle {
        id: head
        width: parent.width; height: 33
        color: Theme.tableHeader
        Repeater {
            model: [
                { t: "Nombre", k: 0, x: 16, w: 0 },
                { t: "Fecha de modificación", k: 2, x: root.xDate },
                { t: "Tamaño", k: 1, x: root.xSize },
                { t: "Tipo", k: 3, x: root.xKind }
            ]
            delegate: Item {
                required property var modelData
                x: modelData.x; height: 33; width: lbl.implicitWidth + 24
                Txt {
                    id: lbl
                    height: 33
                    text: modelData.t
                    color: root.ctl.model.sortKey === modelData.k ? Theme.text : Theme.textDim
                    font.pixelSize: Theme.fontSmall + 1
                }
                Icon {
                    visible: root.ctl.model.sortKey === modelData.k
                    x: lbl.implicitWidth + 4; anchors.verticalCenter: parent.verticalCenter
                    name: root.ctl.model.sortAscending ? "up" : "chevronDown"
                    size: 12; color: Theme.accentLabel
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sortBy(modelData.k)
                }
            }
        }
    }

    ListView {
        id: list
        anchors { top: head.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
        model: root.ctl.model
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: DScrollBar {}

        MouseArea {
            parent: list.contentItem
            z: -1
            width: Math.max(list.width, list.contentWidth)
            height: Math.max(list.height, list.contentHeight)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => {
                list.forceActiveFocus()
                root.ctl.model.clearSelection()
                if (m.button === Qt.RightButton) {
                    const p = mapToItem(null, m.x, m.y)
                    root.backgroundContext(p.x, p.y)
                }
            }
        }

        delegate: Item {
            id: row
            required property int index
            required property string name
            required property string path
            required property bool isDir
            required property string suffix
            required property string modifiedText
            required property string sizeText
            required property string kind
            required property string location
            required property bool selected
            required property bool hidden
            width: list.width; height: 40
            opacity: hidden ? 0.55 : 1

            Rectangle {
                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                radius: 9
                color: row.selected ? Theme.selection : (area.containsMouse ? Theme.card : "transparent")
                border.width: row.selected ? 1 : 0
                border.color: Theme.selectionBorder
            }
            FileTypeIcon {
                x: 16; anchors.verticalCenter: parent.verticalCenter
                size: 24; isDir: row.isDir; suffix: row.suffix
            }
            Column {
                x: 54; anchors.verticalCenter: parent.verticalCenter
                width: root.xDate - 54 - 12
                Txt { width: parent.width; text: row.name; font.pixelSize: Theme.fontBase + 0.5 }
                Txt {
                    visible: row.location !== ""
                    width: parent.width; text: row.location
                    color: Theme.textFaint; font.pixelSize: Theme.fontSmall - 1
                }
            }
            Txt {
                x: root.xDate
                width: root.colDate - 10; anchors.verticalCenter: parent.verticalCenter
                text: row.modifiedText
            }
            Txt {
                x: root.xSize
                width: root.colSize - 10; anchors.verticalCenter: parent.verticalCenter
                text: row.sizeText
            }
            Txt {
                x: root.xKind
                width: root.colKind - 6; anchors.verticalCenter: parent.verticalCenter
                text: row.kind; color: Theme.textDim
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                    list.forceActiveFocus()
                    if (m.button === Qt.RightButton) {
                        if (!row.selected) root.ctl.model.select(row.index, false, false)
                        const p = mapToItem(null, m.x, m.y)
                        root.itemContext(row.index, p.x, p.y)
                    } else {
                        root.ctl.model.select(row.index, (m.modifiers & Qt.ControlModifier) !== 0, (m.modifiers & Qt.ShiftModifier) !== 0)
                    }
                }
                onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) root.ctl.openItem(row.path) }
            }
        }
    }
}
