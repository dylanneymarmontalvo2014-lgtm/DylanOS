import QtQuick
import DylanOS.Explorer

Column {
    id: root
    property string icon: "folder"
    property string title
    property string detail
    property string actionText
    property color tint: Theme.textFaint
    signal action()

    spacing: 10
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 76; height: 76; radius: 38
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1; border.color: Theme.hairline
        Icon { anchors.centerIn: parent; name: root.icon; size: 32; color: root.tint; strokeWidth: 1.5 }
    }
    Item { width: 1; height: 4 }
    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.title
        font.pixelSize: Theme.fontSection
        font.weight: Font.Medium
    }
    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(420, implicitWidth)
        text: root.detail
        color: Theme.textDim
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideNone
    }
    DButton {
        visible: root.actionText !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.actionText
        variant: "outline"
        onClicked: root.action()
    }
}
