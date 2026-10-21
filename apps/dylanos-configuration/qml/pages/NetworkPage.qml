import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Red e Internet: Wi-Fi real vía NetworkManager (nmcli).
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property var state: ({ wifiEnabled: false, networks: [] })

    function refresh() { state = System.network() }
    Component.onCompleted: Qt.callLater(refresh)
    Connections {
        target: System
        function onTaskDone(tag, ok, output) {
            if (tag.toString().startsWith("wifi:")) {
                toast.show(ok ? "Conectado a " + tag.toString().substring(5) : ("No se pudo conectar: " + output))
                root.refresh()
            }
        }
    }

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: root.state.wifiEnabled ? "wifi" : "wifi-off"
                title: "Wi-Fi"
                desc: root.state.wifiEnabled ? (root.state.connectedSsid ? "Conectado a " + root.state.connectedSsid : "Sin conexión") : "Sin conexión inalámbrica"
                DToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.state.wifiEnabled === true
                    onToggled: function (v) {
                        System.setWifi(v)
                        root.refresh()
                    }
                }
            }
            RowItem {
                width: parent.width
                icon: "network"
                title: "Ethernet"
                desc: root.state.ethernet ? "Conectado por cable" : "Cable desconectado"
                last: true
                BadgePill {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.state.ethernet ? "Conectado" : "Sin cable"
                    tone: root.state.ethernet ? "#3ecf6e" : Theme.c.textDim
                }
            }
        }

        Text { text: "Redes disponibles"; font.pixelSize: 18; color: Theme.c.text }

        EmptyState {
            visible: !root.state.wifiEnabled
            width: parent.width
            icon: "wifi-off"
            title: "Wi-Fi desactivado"
            desc: "Actívalo para ver las redes disponibles."
        }

        GroupBox {
            visible: root.state.wifiEnabled && (root.state.networks || []).length > 0
            width: parent.width
            Repeater {
                model: root.state.networks || []
                delegate: RowItem {
                    required property var modelData
                    required property int index
                    width: parent.width
                    icon: "wifi"
                    title: modelData.ssid || "(red oculta)"
                    desc: (modelData.active ? "Conectado · " : "") + "Señal " + modelData.signal + "%" + (modelData.secure ? " · Protegida" : " · Abierta")
                    last: index === (root.state.networks || []).length - 1
                    LucideIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.secure
                        name: "lock"
                        color: Theme.c.textDim
                        size: 15
                    }
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !modelData.active
                        text: "Conectar"
                        onClicked: {
                            if (modelData.secure)
                                passwordDialog.openFor(modelData.ssid)
                            else
                                System.connectWifi(modelData.ssid, "")
                        }
                    }
                }
            }
        }

        Text { text: "Configuración de red"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "shield"
                title: "VPN, proxy y DNS"
                desc: "Se gestionan en el módulo de red nativo"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir red"
                    onClicked: System.openKcm(["kcm_networkmanagement"])
                }
            }
        }
    }

    Dlg {
        id: passwordDialog
        property string ssid: ""
        function openFor(target) {
            ssid = target
            passwordInput.text = ""
            open()
        }
        title: "Conectar a " + ssid
        width: 440
        Text {
            width: parent.width
            text: "Introduce la contraseña de la red protegida."
            font.pixelSize: 14
            color: Theme.c.textDim
            wrapMode: Text.WordWrap
        }
        Rectangle {
            width: parent.width
            height: 40
            radius: Theme.radiusControl
            color: Theme.c.field
            border.width: 1
            border.color: passwordInput.activeFocus ? Theme.accent : Theme.c.border
            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.margins: 10
                echoMode: TextInput.Password
                color: Theme.c.text
                font.pixelSize: 14
                focus: true
            }
        }
        ActionButton {
            text: "Cancelar"
            onClicked: passwordDialog.close()
        }
        ActionButton {
            text: "Conectar"
            variant: "primary"
            onClicked: {
                System.connectWifi(passwordDialog.ssid, passwordInput.text)
                passwordDialog.close()
            }
        }
    }

    Toast {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 70
    }
}
