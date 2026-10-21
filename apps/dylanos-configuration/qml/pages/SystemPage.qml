import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Página de inicio del prototipo: tarjeta de equipo + configuración rápida.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property var info: ({})
    property var net: ({})
    property var bt: ({})
    property var storage: ({})

    function refresh() {
        info = System.sysInfo()
        net = System.network()
        bt = System.bluetooth()
        storage = System.storage()
    }
    Component.onCompleted: Qt.callLater(refresh)

    Column {
        id: col
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        // ---- Tarjeta de equipo ----
        Rectangle {
            width: parent.width
            height: 190
            radius: 16
            color: Theme.c.surface
            border.width: 1
            border.color: Theme.c.border

            Row {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 32

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "qrc:/assets/logo.png"
                    fillMode: Image.PreserveAspectFit
                    width: 118
                    height: 118
                    mipmap: true
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text { text: "DylanOS"; font.pixelSize: 22; color: Theme.c.text }
                    Row {
                        spacing: 10
                        Text { text: "Versión 1.0 Beta"; font.pixelSize: 16; color: Theme.c.text }
                        BadgePill { anchors.verticalCenter: parent.verticalCenter; text: "Estable" }
                    }
                    Text {
                        width: 220
                        text: "El sistema operativo diseñado por Dylan."
                        font.pixelSize: 14
                        color: Theme.c.textDim
                        wrapMode: Text.WordWrap
                    }
                }
                Item { width: 1; height: 1 }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    Repeater {
                        model: [
                            { icon: "laptop", k: "Dispositivo", v: root.info.device || root.info.hostname || "—" },
                            { icon: "cpu", k: "Procesador", v: root.info.cpu || "—" },
                            { icon: "memory-stick", k: "Memoria RAM", v: root.info.memoryGb || "—" },
                            { icon: "hard-drive", k: "Almacenamiento", v: (root.storage.freeGb || 0) + " GB disponibles" }
                        ]
                        delegate: Row {
                            spacing: 14
                            LucideIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: modelData.icon
                                color: Theme.c.textDim
                                size: 20
                            }
                            Column {
                                Text { text: modelData.k; font.pixelSize: 13; color: Theme.c.textDim }
                                Text { text: modelData.v; font.pixelSize: 14; color: Theme.c.text }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                width: 130
                height: 38
                radius: Theme.radiusControl
                color: Theme.c.surfaceStrong
                border.width: 1
                border.color: Theme.c.border
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "Ver detalles"; font.pixelSize: 14; color: Theme.c.text }
                    LucideIcon { anchors.verticalCenter: parent.verticalCenter; name: "chevron-right"; color: Theme.c.textDim; size: 16 }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Window.window.go("about")
                }
            }
        }

        Text { text: "Configuración rápida"; font.pixelSize: 18; color: Theme.c.text }

        Flow {
            width: parent.width
            spacing: 16

            Repeater {
                model: [
                    { icon: "wifi", color: "#d4202f", title: "Wi-Fi", toggle: true,
                      desc: root.net.wifiEnabled ? (root.net.connectedSsid ? "Conectado a " + root.net.connectedSsid : "Activado") : "Desactivado" },
                    { icon: "bluetooth", color: "#2f7be8", title: "Bluetooth", toggle: true,
                      desc: root.bt.powered ? "Activado" : "Desactivado" },
                    { icon: Theme.dark ? "moon" : "sun", color: "#c9c3c4", title: Theme.dark ? "Modo oscuro" : "Modo claro", desc: "Temas y colores", route: "personalization", tab: "Apariencia" },
                    { icon: "sun", color: "#d4202f", title: "Pantalla", desc: "Brillo, escala, resolución", route: "display" },
                    { icon: "volume-2", color: "#d4202f", title: "Sonido", desc: "Volumen, salida, entrada", route: "sound" },
                    { icon: "image", color: "#d4202f", title: "Fondo de pantalla", desc: "Temas del escritorio", route: "personalization", tab: "Fondo de pantalla" },
                    { icon: "refresh-cw", color: "#d4202f", title: "Actualizaciones", desc: "Sistema y actualizaciones", route: "updates" },
                    { icon: "hard-drive", color: "#d4202f", title: "Almacenamiento", desc: (root.storage.freeGb || 0) + " GB disponibles", route: "storage" },
                    { icon: "battery", color: "#4caf50", title: "Batería", desc: "Energía y suspensión", route: "power" },
                    { icon: "user", color: "#3d8bf0", title: "Cuentas", desc: "Tu información, inicio de sesión", route: "accounts" },
                    { icon: "bell", color: "#d4202f", title: "Notificaciones", desc: "Alertas y notificaciones", route: "notifications" },
                    { icon: "lock", color: "#d4202f", title: "Privacidad", desc: "Permisos y bloqueo", route: "privacy" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: (col.width - 32) / 3
                    height: 84
                    radius: Theme.radiusCard
                    color: quickMouse.containsMouse ? Theme.c.surfaceHover : Theme.c.surface
                    border.width: 1
                    border.color: Theme.c.border

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16
                        IconTile {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: modelData.icon
                            tileColor: modelData.color
                            size: 48
                            plain: true
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 140
                            Text { width: parent.width; text: modelData.title; font.pixelSize: 16; color: Theme.c.text; elide: Text.ElideRight }
                            Text { width: parent.width; text: modelData.desc; font.pixelSize: 14; color: Theme.c.textDim; elide: Text.ElideRight }
                        }
                        DToggle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.toggle !== undefined
                            on: modelData.title === "Wi-Fi" ? (root.net.wifiEnabled || false) : (root.bt.powered || false)
                            onToggled: function (v) {
                                if (modelData.title === "Wi-Fi")
                                    System.setWifi(v)
                                else
                                    System.setBluetooth(v)
                                root.refresh()
                            }
                        }
                        LucideIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.toggle === undefined
                            name: "chevron-right"
                            color: Theme.c.textDim
                            size: 20
                        }
                    }
                    MouseArea {
                        id: quickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Window.window.go(modelData.route || "system", modelData.tab || "")
                    }
                }
            }
        }
    }
}

