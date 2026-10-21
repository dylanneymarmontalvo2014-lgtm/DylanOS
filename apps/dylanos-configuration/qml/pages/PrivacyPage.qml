import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Privacidad y seguridad: bloqueo de pantalla real + permisos honestos.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property bool autolock: !System.configBool("kscreenlockerrc", "Daemon", "Autolock") || true
    property int lockTimeout: parseInt(System.configString("kscreenlockerrc", "Daemon", "Timeout") || "5", 10)

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        Text { text: "Bloqueo de pantalla"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "lock"
                title: "Bloquear pantalla al suspender"
                DToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    on: !System.configBool("kscreenlockerrc", "Daemon", "LockOnResume") || true
                    onToggled: function (v) {
                        System.writeConfig("kscreenlockerrc", "Daemon", "LockOnResume", v ? "true" : "false")
                    }
                }
            }
            RowItem {
                width: parent.width
                title: "Bloqueo automático"
                desc: "Tiempo de inactividad antes de bloquear"
                last: true
                DSelect {
                    anchors.verticalCenter: parent.verticalCenter
                    menuWidth: 190
                    value: {
                        const t = parseInt(System.configString("kscreenlockerrc", "Daemon", "Timeout") || "5", 10)
                        return t === 0 ? "Nunca" : t + " minuto" + (t === 1 ? "" : "s")
                    }
                    options: ["1 minuto", "5 minutos", "15 minutos", "Nunca"]
                    onPicked: function (v) {
                        const minutes = v === "Nunca" ? 0 : parseInt(v, 10)
                        System.writeConfig("kscreenlockerrc", "Daemon", "Timeout", String(minutes))
                        System.writeConfig("kscreenlockerrc", "Daemon", "Autolock", v === "Nunca" ? "false" : "true")
                    }
                }
            }
        }

        Text { text: "Permisos de aplicaciones"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "camera"
                title: "Cámara"
                desc: "Los permisos por aplicación no están disponibles todavía"
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Pendiente"; font.pixelSize: 12; color: Theme.c.textDim }
            }
            RowItem {
                width: parent.width
                icon: "mic"
                title: "Micrófono"
                desc: "Los permisos por aplicación no están disponibles todavía"
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Pendiente"; font.pixelSize: 12; color: Theme.c.textDim }
            }
            RowItem {
                width: parent.width
                icon: "map-pin"
                title: "Ubicación"
                desc: "Servicio de geolocalización de Plasma"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir ajustes"
                    onClicked: System.openKcm(["kcm_location", "kcm_energyinfo"])
                }
            }
        }

        Text { text: "Privacidad"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "eye"
                title: "Compartir datos de uso anónimos"
                desc: "DylanOS no incluye telemetría: no se envía ningún dato"
                last: true
                BadgePill { anchors.verticalCenter: parent.verticalCenter; text: "Sin telemetría"; tone: "#3ecf6e" }
            }
        }
    }
}
