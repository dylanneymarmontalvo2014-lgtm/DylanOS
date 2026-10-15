import QtQuick
import QtQuick.Layouts
import DylanOS

// Glow panel with 16px padding whose height follows its content.
Item {
    id: root
    property int pad: 16
    property bool glow: true
    default property alias content: col.data
    implicitHeight: col.implicitHeight + 2 * pad
    RoundedBox { anchors.fill: parent; glow: root.glow; fill: root.glow ? Colors.panel : Colors.surface60 }
    ColumnLayout { id: col; x: root.pad; y: root.pad; width: root.width - 2 * root.pad; spacing: 0 }
}
