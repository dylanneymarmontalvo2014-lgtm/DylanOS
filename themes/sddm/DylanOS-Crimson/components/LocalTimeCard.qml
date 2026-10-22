import QtQuick 2.15
SideCard {
    id: card
    title: "Fecha local"
    height: 118
    property string displayedDate: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: card.displayedDate = Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
    }
    Text {
        anchors.centerIn: parent
        text: card.displayedDate
        color: "#FFFFFF"; font.pixelSize: 14; wrapMode: Text.Wrap
    }
}
