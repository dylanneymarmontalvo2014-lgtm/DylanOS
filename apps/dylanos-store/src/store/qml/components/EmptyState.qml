import QtQuick
import QtQuick.Layouts
import DylanOS

Item {
    id: root
    property string iconName: "PackageOpen"
    property string title
    property string text
    property bool error: false
    default property alias actions: actionFlow.data
    implicitHeight: col.implicitHeight + 112
    Accessible.role: Accessible.StaticText
    Accessible.name: title

    RoundedBox { anchors.fill: parent; fill: "transparent"; dashed: true }

    ColumnLayout {
        id: col
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 56 }
        width: Math.min(384, parent.width - 48)
        spacing: 0
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 56; Layout.preferredHeight: 56
            Layout.bottomMargin: 16
            radius: 16
            color: root.error ? Colors.alpha(Colors.crimson, 0.2) : Colors.white(0.06)
            Icon { anchors.centerIn: parent; name: root.iconName; size: 26; color: root.error ? Colors.red300 : Colors.dim }
        }
        Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.title; font.pixelSize: Typography.lg; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
        Txt { Layout.fillWidth: true; Layout.topMargin: 4; horizontalAlignment: Text.AlignHCenter; text: root.text; color: Colors.dim; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap }
        Flow {
            id: actionFlow
            visible: children.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            Layout.maximumWidth: col.width
            spacing: 8
        }
    }
}
