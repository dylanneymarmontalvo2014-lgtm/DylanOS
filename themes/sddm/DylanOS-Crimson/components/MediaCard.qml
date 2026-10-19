import QtQuick 2.15

// En reproducción (referencia visual; MPRIS no existe fuera de la sesión).
SideCard {
    title: "En reproducción"
    height: 148

    Column {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 2
        anchors.bottomMargin: 12
        spacing: 8

        Row {
            spacing: 12
            Rectangle {
                width: 52; height: 52; radius: 8; color: "#3D0A12"
                Image { source: "../logo.png"; width: 30; height: 30; anchors.centerIn: parent; mipmap: true }
            }
            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "Dream It Possible"; font.pixelSize: 14; font.weight: Font.DemiBold; color: "#FFFFFF" }
                Text { text: "Delacey"; font.pixelSize: 12; color: "#B3B3B3" }
            }
        }

        Item {
            width: parent.width
            height: 12
            Text { text: "1:23"; font.pixelSize: 10; color: "#B3B3B3"; anchors.left: parent.left }
            Text { text: "3:24"; font.pixelSize: 10; color: "#B3B3B3"; anchors.right: parent.right }
        }

        Rectangle {
            width: parent.width; height: 4; radius: 2; color: "#2E2E2E"
            Rectangle { width: parent.width * 0.38; height: 4; radius: 2; color: "#DC143C" }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 34
            Image { source: "../images/media-skip-backward.svg"; width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter }
            Image { source: "../images/media-playback-pause.svg"; width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter }
            Image { source: "../images/media-skip-forward.svg"; width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}