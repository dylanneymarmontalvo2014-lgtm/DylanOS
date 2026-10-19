import QtQuick 2.15

// Próximo evento (contenido de referencia; sin acceso a datos en el greeter).
SideCard {
    title: "Próximo evento"
    height: 96

    Row {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 2
        anchors.bottomMargin: 8
        spacing: 14
        Rectangle {
            width: 42; height: 42; radius: 10; color: "#242424"
            anchors.verticalCenter: parent.verticalCenter
            Image { source: "../images/calendar.svg"; width: 24; height: 24; anchors.centerIn: parent }
        }
        Column {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            Text { text: "Reunión de proyecto"; font.pixelSize: 14; font.weight: Font.DemiBold; color: "#FFFFFF" }
            Text { text: "Mañana"; font.pixelSize: 12; color: "#B3B3B3" }
            Text { text: "10:00 AM – 11:30 AM"; font.pixelSize: 11; color: "#8E8E93" }
        }
    }
}