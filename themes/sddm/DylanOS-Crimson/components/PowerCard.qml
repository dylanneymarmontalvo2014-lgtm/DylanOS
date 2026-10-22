import QtQuick 2.15
SideCard {
    title: "Energía"
    height: 153
    Text {
        anchors.left: parent.left; anchors.leftMargin: 16
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: "Apagado: " + (sddm.canPowerOff ? "disponible" : "no disponible") + "\nReinicio: " + (sddm.canReboot ? "disponible" : "no disponible") + "\nSuspensión: " + (sddm.canSuspend ? "disponible" : "no disponible")
        color: "#FFFFFF"; font.pixelSize: 13; lineHeight: 1.25
    }
}
