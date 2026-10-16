import QtQuick
import QtQuick.Controls.Basic
import DylanOS.Explorer

// The "Inicio" screen from the reference: folder cards + recent files table.
Flickable {
    id: root
    required property var ctl
    required property var places
    signal folderMenu(var folder, real x, real y)
    signal recentMenu(var file, real x, real y)

    property bool showAll: false
    property string selectedRecent

    clip: true
    contentHeight: content.implicitHeight + 40
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: DScrollBar {}

    Column {
        id: content
        x: Theme.pagePadding
        y: 20
        width: root.width - Theme.pagePadding * 2
        spacing: 0

        Txt {
            text: "Carpetas"
            font.pixelSize: Theme.fontSection
            font.weight: Font.Medium
            height: 36
        }
        Item { width: 1; height: 8 }

        Grid {
            id: grid
            columns: 4
            columnSpacing: 17
            rowSpacing: 17
            readonly property real cellW: (content.width - columnSpacing * 3) / 4
            Repeater {
                model: root.places.homeFolders
                delegate: FolderCard {
                    required property var modelData
                    width: grid.cellW
                    name: modelData.name
                    countText: modelData.countText
                    glyph: modelData.icon
                    onOpened: root.ctl.navigate(modelData.path)
                    onMenuRequested: (x, y) => root.folderMenu(modelData, x, y)
                }
            }
        }

        Item { width: 1; height: 26 }
        Item {
            width: parent.width; height: 38
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "Archivos recientes"
                font.pixelSize: Theme.fontSection
                font.weight: Font.Medium
            }
            Rectangle {
                id: seeAll
                visible: root.places.recentFiles.length > 6
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                width: sa.implicitWidth + 44; height: 32; radius: 9
                color: seeArea.containsMouse ? Qt.rgba(0.9, 0.13, 0.18, 0.12) : "transparent"
                border.width: 1; border.color: Theme.accentDeep
                Row {
                    id: sa
                    anchors.centerIn: parent
                    spacing: 14
                    Txt { text: root.showAll ? "Ver menos" : "Ver todo"; color: Theme.accentLabel; anchors.verticalCenter: parent.verticalCenter }
                    Icon { name: root.showAll ? "up" : "forward"; size: 15; color: Theme.accentLabel; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: seeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showAll = !root.showAll
                }
            }
        }
        Item { width: 1; height: 4 }

        RecentTable {
            width: parent.width
            files: root.places.recentFiles
            limit: root.showAll ? 50 : 6
            selectedPath: root.selectedRecent
            onSelected: (p) => root.selectedRecent = p
            onOpened: (p) => root.ctl.openItem(p)
            onMenuRequested: (f, x, y) => root.recentMenu(f, x, y)
        }
    }
}
