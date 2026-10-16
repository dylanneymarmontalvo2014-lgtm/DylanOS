import QtQuick
import DylanOS.Explorer

Rectangle {
    id: root
    property string kind: "info"
    property string message

    function show(k, m) { kind = k; message = m; shown = true; hide.restart() }
    property bool shown: false

    readonly property color tint: kind === "success" ? Theme.success : kind === "error" ? Theme.danger : Theme.info
    width: Math.min(560, row.implicitWidth + 40)
    height: 46
    radius: 14
    color: "#241517"
    border.width: 1
    border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.5)
    opacity: shown ? 1 : 0
    visible: opacity > 0
    transform: Translate { y: root.shown ? 0 : 14; Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.kind === "success" ? "check" : root.kind === "error" ? "warning" : "info"
            size: 18; color: root.tint
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 480)
            text: root.message
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.shown = false }
    Timer { id: hide; interval: 4200; onTriggered: root.shown = false }
}
