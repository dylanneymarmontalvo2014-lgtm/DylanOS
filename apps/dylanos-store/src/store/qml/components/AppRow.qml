import QtQuick
import QtQuick.Layouts
import DylanOS

Item {
    id: root
    property var app
    property int rank: 0
    property string extra: ""
    implicitHeight: 56
    Accessible.role: Accessible.Link
    Accessible.name: app ? app.name : ""
    activeFocusOnTab: true
    Keys.onReturnPressed: Nav.go("app", app.appId)

    Rectangle { anchors.fill: parent; radius: Metrics.radiusCard; color: hh.hovered ? Colors.white(0.05) : "transparent" }
    Rectangle { anchors.fill: parent; anchors.margins: -2; radius: 14; color: "transparent"; border.width: 2; border.color: Colors.crimsonHi; visible: root.activeFocus }
    HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: Nav.go("app", root.app.appId) }

    RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        spacing: 12
        Txt { visible: root.rank > 0; Layout.preferredWidth: 16; horizontalAlignment: Text.AlignHCenter; text: root.rank; color: Colors.faint; font.pixelSize: Typography.sm }
        AppIcon { app: root.app; size: 40 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Txt { Layout.fillWidth: true; text: root.app.name; elide: Text.ElideRight; font.pixelSize: Typography.sm; font.weight: Font.Medium }
            Txt { Layout.fillWidth: true; text: root.extra !== "" ? root.extra : root.app.categoryLabel; elide: Text.ElideRight; color: Colors.dim; font.pixelSize: Typography.xs }
        }
        ActionButton { app: root.app; small: true }
    }
}
