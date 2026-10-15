import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import DylanOS

// Labelled dropdown. options: [[value, label], ...]
RowLayout {
    id: root
    property string label
    property string value
    property var options: []
    signal picked(string value)
    spacing: 8

    Txt { visible: root.label !== ""; text: root.label; color: Colors.dim; font.pixelSize: Typography.xs }
    ComboBox {
        id: cb
        implicitHeight: 36
        implicitWidth: Math.max(110, metrics.width + 52)
        model: root.options.map(o => o[1])
        currentIndex: Math.max(0, root.options.findIndex(o => o[0] === root.value))
        onActivated: i => root.picked(root.options[i][0])
        Accessible.name: root.label
        TextMetrics { id: metrics; font.family: Typography.family; font.pixelSize: Typography.sm; text: root.options.reduce((a, o) => o[1].length > a.length ? o[1] : a, "") }
        HoverHandler { cursorShape: Qt.PointingHandCursor }

        background: Rectangle {
            radius: Metrics.radiusControl
            color: Colors.surface2
            border.width: cb.visualFocus ? 2 : 1
            border.color: cb.visualFocus ? Colors.crimsonHi : Colors.line
        }
        contentItem: Txt { leftPadding: 10; rightPadding: 28; text: cb.displayText; font.pixelSize: Typography.sm; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        indicator: Icon { x: cb.width - width - 8; y: (cb.height - height) / 2; name: "ChevronDown"; size: 14; color: Colors.dim }
        delegate: ItemDelegate {
            required property int index
            required property string modelData
            width: cb.width
            height: 34
            highlighted: cb.highlightedIndex === index
            contentItem: Txt { text: modelData; font.pixelSize: Typography.sm; color: highlighted ? "white" : Colors.fg; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: highlighted ? Colors.crimson : "transparent"; radius: 6 }
        }
        popup: Popup {
            y: cb.height + 4
            width: Math.max(cb.width, 140)
            padding: 4
            implicitHeight: contentItem.implicitHeight + 8
            contentItem: ListView { implicitHeight: contentHeight; model: cb.popup.visible ? cb.delegateModel : null; clip: true }
            background: Rectangle { radius: 10; color: Colors.surface2; border.width: 1; border.color: Colors.line }
        }
    }
}
