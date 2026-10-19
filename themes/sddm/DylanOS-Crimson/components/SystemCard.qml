import QtQuick 2.15

// Sistema: anillo de uso (contenido de referencia; el greeter no lee sensores).
SideCard {
    title: "Sistema"
    height: 136

    Row {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 2
        anchors.bottomMargin: 8
        spacing: 16

        Item {
            width: 82; height: 82
            anchors.verticalCenter: parent.verticalCenter
            Canvas {
                id: ring
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.lineWidth = 8
                    ctx.strokeStyle = "#2E2E2E"
                    ctx.beginPath()
                    ctx.arc(width / 2, height / 2, width / 2 - 6, 0, Math.PI * 2)
                    ctx.stroke()
                    ctx.strokeStyle = "#DC143C"
                    ctx.beginPath()
                    ctx.arc(width / 2, height / 2, width / 2 - 6, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * 0.72)
                    ctx.stroke()
                }
            }
            Text {
                anchors.centerIn: parent
                text: "72%"
                font.pixelSize: 18; font.weight: Font.DemiBold; color: "#FFFFFF"
            }
        }

        Column {
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter
            Column {
                spacing: 1
                Text { text: "Batería"; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF" }
                Text { text: "100%"; font.pixelSize: 12; color: "#B3B3B3" }
            }
            Column {
                spacing: 1
                Text { text: "Almacenamiento"; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF" }
                Text { text: "237 GB libres"; font.pixelSize: 12; color: "#B3B3B3" }
            }
        }
    }
}