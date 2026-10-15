import QtQuick
import DylanOS

// CSS `repeat(auto-fill, minmax(min, 1fr))` equivalent. Cells always share the free width.
Item {
    id: root
    property real minCell: Metrics.cardMinWidth
    property real spacing: Metrics.gap
    property alias model: rep.model
    property Component delegate
    readonly property int columns: Math.max(1, Math.floor((width + spacing) / (minCell + spacing)))
    readonly property real cellWidth: (width - spacing * (columns - 1)) / columns
    property bool stretchRows: true // CSS grid default: cells in a row share the tallest height
    property int rev: 0
    readonly property var rowHeights: {
        void rev
        const hs = []
        for (let k = 0; k < rep.count; ++k) {
            const it = rep.itemAt(k)
            const r = Math.floor(k / columns)
            hs[r] = Math.max(hs[r] || 0, it ? it.implicitHeight : 0)
        }
        return hs
    }
    implicitHeight: grid.implicitHeight
    height: implicitHeight

    Grid {
        id: grid
        width: root.width
        columns: root.columns
        columnSpacing: root.spacing
        rowSpacing: root.spacing
        Repeater {
            id: rep
            delegate: root.delegate
            onItemAdded: (i, item) => {
                item.width = Qt.binding(() => root.cellWidth)
                Qt.callLater(() => ++root.rev)
                if (root.stretchRows)
                    item.height = Qt.binding(() => { const h = root.rowHeights[Math.floor(i / root.columns)] || item.implicitHeight; return h })
            }
        }
    }
}
