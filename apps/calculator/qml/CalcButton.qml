import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: ""
    property color bgColor: "#1c1c1c"
    property color textColor: "#ffffff"

    signal clicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 64
    radius: height / 2
    color: mouseArea.pressed ? Qt.lighter(bgColor, 1.25) : bgColor

    Behavior on color {
        ColorAnimation { duration: 90 }
    }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.textColor
        font.pixelSize: 22
        font.weight: Font.Medium
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
