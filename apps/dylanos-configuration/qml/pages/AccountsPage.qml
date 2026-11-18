import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Cuentas: usuario real + gestión nativa de usuarios y sesión.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property var user: System.userInfo()

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        Rectangle {
            width: parent.width
            height: 112
            radius: Theme.radiusCard
            color: Theme.c.surface
            border.width: 1
            border.color: Theme.c.border

            Row {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 20
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 72
                    height: 72
                    radius: 36
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#ff3a4d" }
                        GradientStop { position: 1; color: "#7d0a16" }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: (root.user.fullName || root.user.name || "?").charAt(0).toUpperCase()
                        font.pixelSize: 28
                        color: "#ffffff"
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 260
                    Text { text: root.user.fullName || root.user.name || "—"; font.pixelSize: 20; color: Theme.c.text }
                    Text { text: "@" + (root.user.name || "") + " · Administrador local"; font.pixelSize: 13; color: Theme.c.textDim }
                }
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Gestionar usuarios"
                    onClicked: System.openKcm(["kcm_users"])
                }
            }
        }

        Text { text: "Inicio de sesión"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "user"
                title: "Inicio de sesión automático"
                desc: "Se configura en el módulo de pantalla de inicio"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir ajustes"
                    // kcm_sddm y kcm_login no existen en DylanOS (el tema SDDM es
                    // propio y no se expone un KCM). El módulo real disponible
                    // para el arranque es el de gestor de sesión de Plasma.
                    onClicked: System.openKcm(["kcm_smserver", "kcm_splashscreen"])
                }
            }
            RowItem {
                width: parent.width
                icon: "volume-2"
                title: "Sonido de inicio de sesión"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir ajustes"
                    onClicked: System.openKcm(["kcm_notifications"])
                }
            }
            RowItem {
                width: parent.width
                title: "Contraseña"
                desc: "Se gestiona desde el sistema; no se solicita aquí"
                last: true
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Pendiente"; font.pixelSize: 12; color: Theme.c.textDim }
            }
        }

        Text { text: "Sesión"; font.pixelSize: 18; color: Theme.c.text }

        ActionButton {
            text: "Cerrar sesión"
            icon: "log-out"
            onClicked: confirmLogout.open()
        }
    }

    Dlg {
        id: confirmLogout
        title: "¿Cerrar sesión?"
        width: 420
        Text {
            width: parent.width
            text: "Se cerrará la sesión actual de Plasma. Las aplicaciones abiertas se cerrarán."
            font.pixelSize: 14
            color: Theme.c.textDim
            wrapMode: Text.WordWrap
        }
        ActionButton {
            text: "Cancelar"
            onClicked: confirmLogout.close()
        }
        ActionButton {
            text: "Cerrar sesión"
            variant: "primary"
            onClicked: {
                confirmLogout.close()
                // En Qt 6 el binario es qdbus6; "qdbus" no existe en DylanOS y el
                // botón de cerrar sesión fallaba sin avisar. Se prueban ambos
                // nombres para no depender del que instale la imagen.
                var dbus = System.has("qdbus6") ? "qdbus6" : "qdbus"
                System.launchDetached(dbus, ["org.kde.ksmserver", "/KSMServer", "logout", "0", "2", "0"])
            }
        }
    }
}
