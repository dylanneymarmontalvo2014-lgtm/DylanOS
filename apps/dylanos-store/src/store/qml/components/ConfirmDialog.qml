import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import DylanOS

Popup {
    id: root
    property string title
    property string message
    property string note
    property string iconName: "AlertTriangle"
    property alias actions: actionRow.data

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    width: Math.min(448, (parent ? parent.width : 448) - 32)
    padding: 24
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle { color: Colors.alpha("black", 0.7) }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
    background: RoundedBox { fill: Colors.panel; radius: 16 }

    contentItem: ColumnLayout {
        spacing: 12
        RowLayout {
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                radius: 12; color: Colors.alpha(Colors.crimson, 0.2)
                Icon { anchors.centerIn: parent; name: root.iconName; size: 18; color: Colors.red300 }
            }
            Txt { Layout.fillWidth: true; text: root.title; font.pixelSize: Typography.lg; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
        }
        Txt { Layout.fillWidth: true; text: root.message + (root.note !== "" ? " " : ""); color: Colors.dim; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap }
        Txt { visible: root.note !== ""; Layout.fillWidth: true; Layout.topMargin: -12; text: root.note; color: Colors.faint; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap }
        Row {
            id: actionRow
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: 12
            spacing: 8
        }
    }
}
