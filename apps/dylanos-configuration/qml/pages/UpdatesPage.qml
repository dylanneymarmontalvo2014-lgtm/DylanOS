import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Sistema y actualizaciones: abre DylanOS Store (motor real de paquetes).
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        Rectangle {
            width: parent.width
            height: 110
            radius: Theme.radiusCard
            color: Theme.c.surface
            border.width: 1
            border.color: Theme.c.border

            Row {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 16
                IconTile {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "circle-check-big"
                    tileColor: "#4caf50"
                    size: 52
                    plain: true
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 320
                    Text { text: "Gestionar actualizaciones"; font.pixelSize: 18; color: Theme.c.text }
                    Text {
                        width: parent.width
                        text: "Las actualizaciones se buscan e instalan desde DylanOS Store, que usa PackageKit, Flatpak y AppStream."
                        font.pixelSize: 13
                        color: Theme.c.textDim
                        wrapMode: Text.WordWrap
                    }
                }
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Buscar actualizaciones"
                    variant: "primary"
                    icon: "download"
                    onClicked: System.launchDetached("dylanos-store", ["--mode", "Update"])
                }
            }
        }

        Text { text: "Opciones"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                title: "Instalar actualizaciones automáticamente"
                desc: "Requiere configurar unattended-upgrades en el sistema"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Pendiente"
                }
            }
            RowItem {
                width: parent.width
                title: "Copias de seguridad"
                desc: "Sin herramienta de copias integrada todavía"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Pendiente"
                }
            }
        }
    }
}
