import QtQuick
import DylanOS.Explorer

Rectangle {
    id: root
    property var files: []
    property int limit: 6
    property string selectedPath
    signal selected(string path)
    signal opened(string path)
    signal menuRequested(var file, real x, real y)

    readonly property real colLoc: width * 0.397
    readonly property real colDate: width * 0.668
    readonly property real colSize: width * 0.875
    readonly property int rowHeight: 41
    readonly property int shown: Math.min(limit, files.length)

    height: 33 + shown * rowHeight + (shown === 0 ? 56 : 0)
    radius: 14
    color: Qt.rgba(1, 1, 1, 0.02)
    border.width: 1
    border.color: Theme.hairline
    clip: true

    Rectangle {
        width: parent.width; height: 33
        color: Theme.tableHeader
        Repeater {
            model: [
                { t: "Nombre", x: 14 }, { t: "Ubicación", x: root.colLoc },
                { t: "Fecha de modificación", x: root.colDate }, { t: "Tamaño", x: root.colSize }
            ]
            delegate: Txt {
                required property var modelData
                x: modelData.x; height: 33
                text: modelData.t
                color: Theme.textDim
                font.pixelSize: Theme.fontSmall + 1
            }
        }
    }

    Txt {
        visible: root.shown === 0
        y: 33; width: parent.width; height: 56
        horizontalAlignment: Text.AlignHCenter
        text: "No hay archivos recientes"
        color: Theme.textFaint
    }

    Column {
        y: 33
        width: parent.width
        Repeater {
            model: root.files.slice(0, root.limit)
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: root.width; height: root.rowHeight
                color: root.selectedPath === modelData.path ? Theme.selection : (rowArea.containsMouse ? Theme.cardHover : "transparent")

                Rectangle { y: 0; width: parent.width; height: 1; color: Theme.hairline }

                FileTypeIcon {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    size: 24
                    suffix: row.modelData.suffix
                }
                Txt {
                    x: 56; width: root.colLoc - 56 - 90
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    font.pixelSize: Theme.fontBase + 0.5
                }
                FolderIcon {
                    x: root.colLoc; anchors.verticalCenter: parent.verticalCenter
                    scaleFactor: 0.31
                }
                Txt {
                    x: root.colLoc + 32; width: root.colDate - root.colLoc - 40
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.location
                }
                Txt {
                    x: root.colDate; width: root.colSize - root.colDate - 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.modifiedText
                }
                Txt {
                    x: root.colSize; width: root.width - root.colSize - 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.sizeText
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (m) => {
                        root.selected(row.modelData.path)
                        if (m.button === Qt.RightButton) {
                            const p = mapToItem(null, m.x, m.y)
                            root.menuRequested(row.modelData, p.x, p.y)
                        }
                    }
                    onDoubleClicked: root.opened(row.modelData.path)
                }
            }
        }
    }
}
