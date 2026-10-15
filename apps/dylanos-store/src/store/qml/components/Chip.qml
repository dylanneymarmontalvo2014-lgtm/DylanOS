import QtQuick
import DylanOS

// tone: neutral | ok | warn | red
Rectangle {
    id: root
    property string tone: "neutral"
    property string text: ""
    property string iconName: ""
    property bool spin: false
    readonly property color fg: tone === "ok" ? Colors.ok : tone === "warn" ? Colors.warn : tone === "red" ? Colors.red300 : Colors.dim
    implicitHeight: 20
    implicitWidth: row.implicitWidth + 16
    radius: 6
    color: tone === "ok" ? Colors.alpha(Colors.ok, 0.15) : tone === "warn" ? Colors.alpha(Colors.warn, 0.15)
         : tone === "red" ? Colors.alpha(Colors.crimson, 0.2) : Colors.white(0.07)
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Icon { visible: root.iconName !== ""; anchors.verticalCenter: parent.verticalCenter; name: root.iconName; size: 12; color: root.fg; spin: root.spin }
        Txt { anchors.verticalCenter: parent.verticalCenter; text: root.text; color: root.fg; font.pixelSize: Typography.tiny; font.weight: Font.Medium }
    }
}
