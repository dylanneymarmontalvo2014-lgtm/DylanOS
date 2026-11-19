// Pie de estado: punto pulsante + texto, y versión real de la app.
import QtQuick
import org.dylanos.process

Rectangle {
    id: footer

    implicitHeight: Theme.footerHeight
    color: Theme.surfaceColor

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Theme.border
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        Rectangle {
            id: dot
            width: 7
            height: 7
            radius: 999
            color: Theme.success
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation { to: 0.45; duration: 1000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
            }
        }

        Text {
            text: qsTr("Sistema en funcionamiento")
            color: Theme.textTertiary
            font.family: Theme.uiFont
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: qsTr("DylanOS Process v%1").arg(Qt.application.version)
        color: Theme.textTertiary
        font.family: Theme.uiFont
        font.pixelSize: 12
    }
}
