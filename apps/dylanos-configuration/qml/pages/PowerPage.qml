import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Energía y batería: perfil real vía power-profiles-daemon.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property var state: ({})

    function refresh() { state = System.power() }
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
                LucideIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.state.battery && root.state.battery.charging ? "battery-charging" : "battery"
                    color: "#4caf50"
                    size: 44
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 220
                    spacing: 8
                    Text {
                        text: root.state.battery && root.state.battery.present
                              ? root.state.battery.percent + "%"
                              : "Sin batería"
                        font.pixelSize: 22
                        color: Theme.c.text
                    }
                    Text {
                        text: root.state.battery && root.state.battery.present
                              ? (root.state.battery.charging ? "Cargando" : "Sobre batería")
                              : "El equipo funciona conectado a la red eléctrica"
                        font.pixelSize: 13
                        color: Theme.c.textDim
                    }
                    Meter {
                        width: parent.width
                        pct: root.state.battery ? root.state.battery.percent : 0
                        barColor: "#4caf50"
                    }
                }
            }
        }

        Text { text: "Modo de energía"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            visible: root.state.available !== false
            RowItem {
                width: parent.width
                icon: "zap"
                title: "Perfil"
                DSegmented {
                    anchors.verticalCenter: parent.verticalCenter
                    value: root.state.profile === "power-saver" ? "Ahorro"
                           : root.state.profile === "performance" ? "Rendimiento" : "Equilibrado"
                    options: ["Ahorro", "Equilibrado", "Rendimiento"]
                    onPicked: function (v) {
                        const map = { "Ahorro": "power-saver", "Equilibrado": "balanced", "Rendimiento": "performance" }
                        System.setPowerProfile(map[v])
                        root.refresh()
                    }
                }
            }
            RowItem {
                width: parent.width
                icon: "battery"
                title: "Ahorro de batería"
                desc: "Reduce el brillo y la actividad en segundo plano"
                last: true
                DToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.state.profile === "power-saver"
                    onToggled: function (v) {
                        System.setPowerProfile(v ? "power-saver" : "balanced")
                        root.refresh()
                    }
                }
            }
        }

        Text { text: "Suspensión"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                title: "Suspender tras inactividad"
                desc: "Se configura en los ajustes de energía de Plasma"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir energía"
                    onClicked: System.openKcm(["kcm_powerdevilprofilesconfig", "kcm_powerdevilglobalconfig"])
                }
            }
        }

        GroupBox {
            width: parent.width
            visible: root.state.available === false
            EmptyState {
                width: parent.width
                icon: "battery"
                title: "Sin gestión de energía"
                desc: "power-profiles-daemon no está disponible en este sistema."
            }
        }
    }
}
