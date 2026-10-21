import QtQuick
import org.dylanos.configuration

// Pestañas de píldoras (Personalización, Aplicaciones).
Row {
    id: root
    property string value: ""
    property var tabs: []
    signal picked(string value)

    spacing: 6
    Repeater {
        model: root.tabs
        delegate: Rectangle {
            required property var modelData
            property bool active: modelData === root.value
            width: label.implicitWidth + 32
            height: 36
            radius: 18
            color: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28) : Theme.c.surface
            border.width: 1
            border.color: active ? Theme.accent : Theme.c.border
            Text {
                id: label
                anchors.centerIn: parent
                text: modelData
                font.pixelSize: 14
                color: parent.active ? Theme.c.text : Theme.c.textDim
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(modelData)
            }
        }
    }
}
