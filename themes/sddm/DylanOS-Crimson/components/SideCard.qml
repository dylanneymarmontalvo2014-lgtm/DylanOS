import QtQuick 2.15

// Tarjeta lateral translúcida del greeter (título carmesí, contenido genérico).
Rectangle {
    id: card
    property string title: ""
    default property alias content: cardBody.data
    width: 308
    radius: 18
    color: Qt.rgba(0.10, 0.10, 0.10, 0.82)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    Text {
        visible: card.title !== ""
        text: card.title
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 16
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: "#DC143C"
    }

    Item {
        id: cardBody
        anchors.fill: parent
        anchors.topMargin: card.title !== "" ? 38 : 0
    }
}
