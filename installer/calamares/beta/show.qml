import QtQuick 2.12
Rectangle {
    color: "#20212b"
    Image { anchors.fill: parent; source: "background.png"; fillMode: Image.PreserveAspectCrop; opacity: 0.45 }
    Column {
        anchors.centerIn: parent; width: parent.width * 0.8; spacing: 20
        Text { text: "Tu próximo comienzo."; color: "white"; font.pixelSize: 30; font.bold: true; width: parent.width; wrapMode: Text.Wrap }
        Text { text: "DylanOS 1.0 Beta"; color: "#f0acba"; font.pixelSize: 20 }
        Text { text: "Archivos, notas y herramientas para crear.\nUn escritorio libre, construido sobre Debian y KDE Plasma."; color: "#e3e3ed"; font.pixelSize: 16; width: parent.width; wrapMode: Text.Wrap }
    }
}
