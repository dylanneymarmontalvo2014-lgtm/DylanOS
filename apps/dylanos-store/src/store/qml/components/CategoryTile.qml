import QtQuick
import QtQuick.Layouts
import DylanOS

// compact: home tile (icon 36 + name + count); otherwise the larger Categories card with description.
Card {
    id: root
    property bool compact: false
    required property var modelData
    readonly property int count: Store.categoryCount(modelData.id)
    implicitHeight: compact ? 66 : Math.max(88, tcol.implicitHeight + 32)
    Accessible.role: Accessible.Button
    Accessible.name: modelData.label
    onClicked: Nav.go("cat", modelData.id)

    RowLayout {
        anchors { fill: parent; margins: compact ? 12 : 16 }
        spacing: 12
        Rectangle {
            Layout.alignment: Qt.AlignTop | (compact ? Qt.AlignVCenter : 0)
            Layout.preferredWidth: compact ? 36 : 44; Layout.preferredHeight: compact ? 36 : 44
            radius: compact ? 8 : 12
            color: Colors.alpha(Colors.crimson, 0.15)
            Icon { anchors.centerIn: parent; name: modelData.icon; size: compact ? 18 : 22; color: Colors.red300 }
        }
        ColumnLayout {
            id: tcol
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            Txt { Layout.fillWidth: true; text: modelData.label; elide: Text.ElideRight; font.pixelSize: compact ? Typography.sm : Typography.body; font.weight: Font.Medium }
            Txt { visible: !compact; Layout.fillWidth: true; Layout.topMargin: 2; text: modelData.desc; color: Colors.dim; font.pixelSize: Typography.xs; wrapMode: Text.WordWrap }
            Txt { Layout.topMargin: compact ? 0 : 8; text: root.count + " aplicaciones"; color: compact ? Colors.dim : Colors.faint; font.pixelSize: Typography.xs }
        }
    }
}
