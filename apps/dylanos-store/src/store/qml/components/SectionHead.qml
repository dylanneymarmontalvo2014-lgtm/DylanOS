import QtQuick
import DylanOS

Item {
    id: root
    property string title
    property string more: "Ver todo"
    property bool hasMore: false
    signal moreClicked()
    implicitHeight: 28 + 12
    implicitWidth: 200

    Txt {
        text: root.title
        font.pixelSize: Typography.lg
        font.weight: Font.DemiBold
        anchors.left: parent.left
        anchors.top: parent.top
        Accessible.role: Accessible.Heading
    }
    AbstractButtonLike {
        visible: root.hasMore
        anchors.right: parent.right
        anchors.top: parent.top
        height: 28
        label: root.more
        onClicked: root.moreClicked()
    }
}
