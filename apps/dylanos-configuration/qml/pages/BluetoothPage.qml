import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Bluetooth y dispositivos: adaptador y dispositivos reales (bluetoothctl).
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    // "state" sin calificar dentro de Items hijos resuelve a la propiedad
    // integrada Item.state (string "") y oculta este objeto: SIEMPRE usar
    // root.state en los bindings. Valores por defecto para que ningún
    // binding bool reciba undefined antes de la primera carga.
    property var state: ({ powered: false, devices: [] })

    function refresh() { state = System.bluetooth() }
    Component.onCompleted: Qt.callLater(refresh)
    Connections {
        target: System
        function onTaskDone(tag, ok, output) {
            if (tag.toString().startsWith("bt:")) {
                toast.show(ok ? "Operación realizada" : ("Error: " + output))
                root.refresh()
            }
        }
    }

    function iconFor(name) {
        const n = (name || "").toLowerCase()
        if (n.includes("head") || n.includes("aura") || n.includes("buds") || n.includes("audio"))
            return "headphones"
        if (n.includes("key") || n.includes("mx"))
            return "keyboard"
        if (n.includes("mouse"))
            return "mouse"
        if (n.includes("phone") || n.includes("tel"))
            return "smartphone"
        return "speaker"
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
                icon: "bluetooth"
                title: "Bluetooth"
                desc: root.state.powered ? "Activado · visible como \"" + (root.state.name || "equipo") + "\"" : "Desactivado"
                last: true
                DToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.state.powered === true
                    onToggled: function (v) {
                        System.setBluetooth(v)
                        root.refresh()
                    }
                }
            }
        }

        EmptyState {
            visible: !root.state.powered
            width: parent.width
            icon: "bluetooth"
            title: "Bluetooth desactivado"
            desc: "Actívalo para ver y conectar dispositivos."
        }

        Text {
            visible: root.state.powered
            text: "Dispositivos emparejados"
            font.pixelSize: 18
            color: Theme.c.text
        }

        EmptyState {
            visible: root.state.powered && (root.state.devices || []).length === 0
            width: parent.width
            icon: "bluetooth"
            title: "Sin dispositivos emparejados"
            desc: "Empareja dispositivos desde su modo de vinculación y vuelve a comprobar la lista."
        }

        GroupBox {
            visible: root.state.powered && (root.state.devices || []).length > 0
            width: parent.width
            Repeater {
                model: root.state.devices || []
                delegate: RowItem {
                    required property var modelData
                    required property int index
                    width: parent.width
                    icon: root.iconFor(modelData.name || "")
                    title: modelData.name || modelData.mac
                    desc: modelData.connected ? "Conectado" : "Emparejado"
                    last: index === (root.state.devices || []).length - 1
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.connected ? "Desconectar" : "Conectar"
                        variant: modelData.connected ? "ghost" : "primary"
                        onClicked: {
                            if (modelData.connected)
                                System.btDisconnect(modelData.mac)
                            else
                                System.btConnect(modelData.mac)
                        }
                    }
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Olvidar"
                        variant: "danger"
                        onClicked: {
                            if (System.btRemove(modelData.mac)) {
                                toast.show("Dispositivo olvidado")
                                root.refresh()
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: root.state.powered
            text: "Para emparejar un dispositivo nuevo, ponlo en modo de vinculación y usa el módulo nativo de Bluetooth."
            width: parent.width
            font.pixelSize: 12
            color: Theme.c.textDim
            wrapMode: Text.WordWrap
        }

        ActionButton {
            visible: root.state.powered
            text: "Abrir módulo de Bluetooth"
            onClicked: System.openKcm(["kcm_bluetooth"])
        }
    }

    Toast {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 70
    }
}
