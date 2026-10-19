import QtQuick 2.15

// Tarjeta del clima: contenido fijo de referencia (un greeter no tiene
// acceso a servicios meteorológicos; la identidad visual es lo que manda).
SideCard {
    title: "Clima"
    height: 204

    Row {
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.leftMargin: 18
        spacing: 16

        Item {
            width: 58; height: 50

            Rectangle {
                width: 22; height: 22; radius: 11
                color: "#DC143C"
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 2
            }
            Image {
                source: "../images/weather-cloud.svg"
                width: 50; height: 36
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                fillMode: Image.PreserveAspectFit
            }
        }

        Column {
            spacing: 1
            Text { text: "19°"; font.pixelSize: 32; font.weight: Font.Medium; color: "#FFFFFF" }
            Text { text: "Nublado"; font.pixelSize: 13; color: "#FFFFFF" }
            Text { text: "Sensación 18°"; font.pixelSize: 11; color: "#B3B3B3" }
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Repeater {
            model: [
                { d: "Mié", t: "23°", s: "14°", i: "../images/weather-cloud.svg" },
                { d: "Jue", t: "24°", s: "15°", i: "../images/weather-sun.svg" },
                { d: "Vie", t: "22°", s: "13°", i: "../images/weather-cloud.svg" },
                { d: "Sáb", t: "20°", s: "12°", i: "../images/weather-cloud.svg" },
                { d: "Dom", t: "21°", s: "13°", i: "../images/weather-sun.svg" }
            ]
            delegate: Column {
                width: 44
                spacing: 3
                Text { text: modelData.d; font.pixelSize: 11; color: "#B3B3B3"; anchors.horizontalCenter: parent.horizontalCenter }
                Image { source: modelData.i; width: 18; height: 18; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: modelData.t; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#FFFFFF"; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: modelData.s; font.pixelSize: 10; color: "#8E8E93"; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }
}