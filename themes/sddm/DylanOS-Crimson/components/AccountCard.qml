import QtQuick 2.15
SideCard {
    title: "Usuario"
    height: 118
    Row {
        anchors.fill: parent
        anchors.leftMargin: 16; anchors.rightMargin: 16
        anchors.topMargin: 4; anchors.bottomMargin: 4
        spacing: 12
        Item {
            width: 50; height: 50
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: width / 2; color: "#242126"; clip: true
                Image { id: profilePhoto; anchors.fill: parent; source: root.userAvatarSource; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: status === Image.Ready }
                Text { anchors.centerIn: parent; text: user.currentText.length ? user.currentText.substring(0, 1).toUpperCase() : ""; color: "#FFFFFF"; font.pixelSize: 20; visible: profilePhoto.status !== Image.Ready }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 62; spacing: 5
            Text { text: user.currentText.length ? user.currentText : "Selecciona un usuario"; color: "#FFFFFF"; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
            Text { text: root.userAvatarSource.length ? "Foto de perfil" : "Inicial: no hay foto configurada"; color: "#B3B3B3"; font.pixelSize: 11; wrapMode: Text.Wrap; width: parent.width }
        }
    }
}
