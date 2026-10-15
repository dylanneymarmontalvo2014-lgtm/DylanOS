import QtQuick
import QtQuick.Layouts
import DylanOS

Rectangle {
    id: root
    property var app
    readonly property var err: Strings.errors[app.errorKind !== "" ? app.errorKind : "download"]
    signal retry()
    radius: Metrics.radiusCard
    color: Colors.dangerBg
    border.width: 1
    border.color: Colors.dangerLine
    implicitHeight: grid.implicitHeight + 32
    Accessible.role: Accessible.AlertMessage
    Accessible.name: err.title

    GridLayout {
        id: grid
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        columns: root.width >= 560 ? 3 : 2
        columnSpacing: 12
        rowSpacing: 12
        Icon { Layout.alignment: Qt.AlignTop; Layout.topMargin: 2; name: "AlertTriangle"; size: 20; color: Colors.red400 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Txt { Layout.fillWidth: true; text: root.err.title; font.weight: Font.Medium }
            Txt { Layout.fillWidth: true; text: root.err.text; color: Colors.dim; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap }
        }
        Row {
            Layout.alignment: Qt.AlignTop
            Layout.columnSpan: root.width >= 560 ? 1 : 2
            spacing: 8
            Btn { small: true; text: root.err.action; iconName: "RotateCcw"; onClicked: root.retry() }
            Btn { small: true; variant: "ghost"; text: "Cancelar"; onClicked: Store.cancel(root.app.appId) }
        }
    }
}
