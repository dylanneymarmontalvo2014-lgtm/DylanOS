import QtQuick
import org.dylanos.configuration

// Grupo segmentado del prototipo: píldoras dentro de un campo redondeado.
Rectangle {
    id: root
    property string value: ""
    property var options: []
    signal picked(string value)

    width: row.implicitWidth + 8
    height: 38
    radius: Theme.radiusTile
    color: Theme.c.field
    border.width: 1
    border.color: Theme.c.border

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Repeater {
            model: root.options
            delegate: Rectangle {
                required property var modelData
                property bool active: modelData === root.value
                width: label.implicitWidth + 28
                height: 30
                radius: 8
                color: active ? Theme.accent : "transparent"
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 13
                    color: parent.active ? "#ffffff" : Theme.c.textDim
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData)
                }
            }
        }
    }
}
