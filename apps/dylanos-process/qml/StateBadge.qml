// Etiqueta de estado con punto de color, como el prototipo.
import QtQuick
import org.dylanos.process

Rectangle {
    id: badge

    property string text
    property color dotColor: Theme.textTertiary
    property int horizontalPadding: 13
    property bool centered: false

    implicitWidth: content.implicitWidth + horizontalPadding * 2
    implicitHeight: 22
    radius: 999
    color: Theme.neutralSubtle

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            width: 6
            height: 6
            radius: 999
            color: badge.dotColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: badge.text
            color: badge.dotColor
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
}
