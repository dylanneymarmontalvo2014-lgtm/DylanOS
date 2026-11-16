import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Sistema y actualizaciones: abre DylanOS Store (motor real de paquetes)
// y gestiona unattended-upgrades real vía SystemService (polkit).
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property var autoUpd: ({})

    function refresh() { autoUpd = System.autoUpdates() }
    Component.onCompleted: Qt.callLater(refresh)

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
                desc: root.autoUpd.available === true
                      ? "unattended-upgrades: seguridad y actualizaciones del sistema"
                      : "unattended-upgrades no está instalado en el sistema"
                Item {
                    width: updControls.width
                    height: 30
                    Row {
                        id: updControls
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        DToggle {
                            visible: root.autoUpd.available === true
                            on: root.autoUpd.enabled === true
                            onToggled: function (v) {
                                if (System.setAutoUpdates(v)) {
                                    root.refresh()
                                    toast.show(v ? "Actualizaciones automáticas activadas"
                                                 : "Actualizaciones automáticas desactivadas")
                                }
                            }
                        }
                        BadgePill {
                            visible: root.autoUpd.available !== true
                            text: "No disponible"
                            tone: Theme.c.textDim
                        }
                    }
                }
            }
            RowItem {
                width: parent.width
                title: "Copias de seguridad"
                desc: "Sin herramienta de copias integrada todavía"
                last: true
                BadgePill {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "No disponible"
                    tone: Theme.c.textDim
                }
            }
        }
    }

    Toast { id: toast; anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 70 }
}
