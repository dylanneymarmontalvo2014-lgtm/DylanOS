// Barra de título DylanOS: logo, nombre y semáforos de la izquierda.
//
// Ventana frameless: los semáforos son los controles reales y la barra arrastra
// con startSystemMove(), como el resto de apps nativas de DylanOS.
import QtQuick
import org.dylanos.process

Rectangle {
    id: titleBar

    property var window

    height: Theme.titleBarHeight
    color: Theme.surfaceColor

    // Línea inferior que separa la barra del contenido.
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: if (titleBar.window) titleBar.window.startSystemMove()
        onDoubleClicked: {
            if (!titleBar.window)
                return
            if (titleBar.window.visibility === Window.Maximized)
                titleBar.window.showNormal()
            else
                titleBar.window.showMaximized()
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Image {
            id: logo
            source: "image://icon/dylanos-process"
            sourceSize.width: 26
            sourceSize.height: 26
            width: 26
            height: 26
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: qsTr("DylanOS Process")
            color: Theme.textPrimary
            font.family: Theme.uiFont
            font.pixelSize: 14
            font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        WindowButton {
            icon: "minimize"
            onClicked: if (titleBar.window) titleBar.window.showMinimized()
        }
        WindowButton {
            icon: "maximize"
            onClicked: {
                if (!titleBar.window)
                    return
                if (titleBar.window.visibility === Window.Maximized)
                    titleBar.window.showNormal()
                else
                    titleBar.window.showMaximized()
            }
        }
        WindowButton {
            icon: "close"
            danger: true
            onClicked: if (titleBar.window) titleBar.window.close()
        }
    }
}
