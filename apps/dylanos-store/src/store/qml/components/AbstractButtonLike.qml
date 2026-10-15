import QtQuick
import QtQuick.Controls.Basic
import DylanOS

// Text link with trailing chevron ("Ver todo >").
AbstractButton {
    id: root
    property string label
    property bool chevron: true
    implicitWidth: row.implicitWidth
    implicitHeight: 28
    hoverEnabled: true
    text: label
    Accessible.name: label
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    contentItem: Row {
        id: row
        spacing: 4
        Txt { anchors.verticalCenter: parent.verticalCenter; text: root.label; font.pixelSize: Typography.sm; color: root.hovered ? "white" : Colors.red400 }
        Icon { visible: root.chevron; anchors.verticalCenter: parent.verticalCenter; name: "ChevronRight"; size: 16; color: root.hovered ? "white" : Colors.red400 }
    }
    background: Rectangle { color: "transparent"; border.width: 2; border.color: Colors.crimsonHi; radius: 4; visible: root.visualFocus }
}
