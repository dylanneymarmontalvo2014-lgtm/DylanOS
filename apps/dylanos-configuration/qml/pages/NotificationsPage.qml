import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Notificaciones: preferencias reales gestionadas por el módulo nativo.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "bell"
                title: "Notificaciones"
                desc: "Permitir notificaciones de aplicaciones y del sistema"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir ajustes"
                    onClicked: System.openKcm(["kcm_notifications"])
                }
            }
            RowItem {
                width: parent.width
                icon: "zap"
                title: "No molestar"
                desc: "Silencia banners y sonidos mientras esté activo"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir ajustes"
                    onClicked: System.openKcm(["kcm_notifications"])
                }
            }
        }

        Text { text: "Preferencias generales"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                title: "Mostrar banners"
                desc: "Se configuran por aplicación en el módulo nativo"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir ajustes"
                    onClicked: System.openKcm(["kcm_notifications"])
                }
            }
            RowItem {
                width: parent.width
                title: "Mostrar en pantalla de bloqueo"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir ajustes"
                    onClicked: System.openKcm(["kcm_notifications"])
                }
            }
            RowItem {
                width: parent.width
                title: "Reproducir sonido"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir ajustes"
                    onClicked: System.openKcm(["kcm_notifications"])
                }
            }
        }

        Text {
            width: parent.width
            text: "La configuración por aplicación se realiza en el módulo nativo de notificaciones de KDE, que DylanOS Configuration reutiliza."
            font.pixelSize: 12
            color: Theme.c.textDim
            wrapMode: Text.WordWrap
        }
    }
}
