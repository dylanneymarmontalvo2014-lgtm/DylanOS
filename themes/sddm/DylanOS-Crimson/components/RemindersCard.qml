import QtQuick 2.15
import QtQuick.Layouts 1.15

// Recordatorios (lista de referencia; el greeter no persiste datos).
SideCard {
    title: "Recordatorios"
    height: 184

    Column {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 2
        anchors.bottomMargin: 12
        spacing: 12

        Repeater {
            model: [
                { t: "Estudiar para examen", done: false },
                { t: "Editar video de DylanTube", done: true },
                { t: "Revisar proyecto DylanOS", done: false },
                { t: "Entrenar", done: false }
            ]
            delegate: Row {
                spacing: 12
                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: modelData.done ? "#DC143C" : "transparent"
                    border.color: modelData.done ? "#DC143C" : "#8A8A8A"
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        visible: modelData.done
                        text: "✓"
                        color: "#FFFFFF"
                        font.pixelSize: 12; font.bold: true
                        anchors.centerIn: parent
                    }
                }
                Text {
                    text: modelData.t
                    font.pixelSize: 13
                    color: modelData.done ? "#B3B3B3" : "#FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}