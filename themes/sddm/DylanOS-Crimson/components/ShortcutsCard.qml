import QtQuick 2.15
import QtQuick.Layouts 1.15

// Atajos rápidos (referencia visual del greeter; los controles reales de
// Wi-Fi/Bluetooth/Modo oscuro viven en el Centro de Control de la sesión).
SideCard {
    title: "Atajos"
    height: 270

    GridLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 2
        anchors.bottomMargin: 12
        columns: 2
        columnSpacing: 14
        rowSpacing: 10

        Repeater {
            model: [
                { i: "../images/moon.svg", l: "Modo oscuro" },
                { i: "../images/bell-off.svg", l: "No molestar" },
                { i: "../images/network-wireless.svg", l: "Wi-Fi" },
                { i: "../images/bluetooth.svg", l: "Bluetooth" }
            ]
            delegate: Column {
                Layout.fillWidth: true
                spacing: 5
                Rectangle {
                    width: 58; height: 44; radius: 12
                    color: "#222222"
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    Image { source: modelData.i; width: 20; height: 20; anchors.centerIn: parent }
                }
                Text {
                    text: modelData.l
                    font.pixelSize: 11; color: "#FFFFFF"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
