import QtQuick
import QtQuick.Layouts
import DylanOS

Card {
    id: root
    property var app
    lift: true
    implicitHeight: col.implicitHeight + 32
    Accessible.name: app ? app.name : ""
    onClicked: Nav.go("app", app.appId)

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 8
        AppIcon { Layout.alignment: Qt.AlignHCenter; app: root.app; size: 56 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Txt { Layout.fillWidth: true; text: root.app.name; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; font.weight: Font.Medium; font.pixelSize: Typography.body }
            Txt { Layout.fillWidth: true; text: root.app.categoryLabel; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; color: Colors.dim; font.pixelSize: Typography.xs }
        }
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 20
            Layout.preferredWidth: badge.implicitWidth
            StatusBadge { id: badge; app: root.app }
        }
        ActionButton { Layout.alignment: Qt.AlignHCenter; app: root.app; small: true; wide: true }
    }
}
