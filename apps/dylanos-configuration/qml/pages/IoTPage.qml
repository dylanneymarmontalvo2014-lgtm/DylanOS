import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth
    property var current: ({})
    property var deviceList: []
    property var appList: []
    property var profileList: []
    property string query: ""

    function refresh() {
        current = IoT.status()
        deviceList = IoT.devices()
        appList = IoT.catalog()
        profileList = IoT.profiles()
    }
    Component.onCompleted: Qt.callLater(refresh)
    Connections { target: IoT; function onChanged() { root.refresh() } }

    Column {
        x: 32; y: 4; width: root.width - 64; spacing: 18
        Row {
            width: parent.width; spacing: 12
            Column {
                width: parent.width - refreshButton.width - 12
                Text { text: "IoT & Embedded Systems"; color: Theme.c.text; font.pixelSize: 25; font.bold: true }
                Text { text: "Hardware detectado y herramientas declaradas para Debian Stable"; color: Theme.c.textDim; font.pixelSize: 13 }
            }
            ActionButton { id: refreshButton; text: "Actualizar"; onClicked: root.refresh() }
        }

        PanelBox {
            width: parent.width
            height: envColumn.implicitHeight + 40
            Column {
                id: envColumn
                width: parent.width; spacing: 12
                SectionTitle { text: "Entorno" }
                Row {
                    width: parent.width; spacing: 16
                    Text { text: "Activar preferencias IoT"; color: Theme.c.text; anchors.verticalCenter: parent.verticalCenter }
                    DToggle { on: IoT.enabled; onToggled: function(value) { IoT.setEnabled(value) } }
                    DSelect {
                        width: 300
                        options: root.profileList.map(function(p) { return p.name })
                        value: root.profileList.find(function(p) { return p.id === IoT.activeProfile })?.name || "IoT Development"
                        onPicked: function(name) {
                            const selected = root.profileList.find(function(p) { return p.name === name })
                            if (selected) IoT.setProfile(selected.id)
                        }
                    }
                    ActionButton { text: "Restaurar respaldo"; onClicked: { IoT.restore(); root.refresh() } }
                }
                Text { text: "Los perfiles guardan la selección y no instalan programas ni inician servicios por su cuenta."; color: Theme.c.textDim; font.pixelSize: 12; wrapMode: Text.WordWrap }
            }
        }

        Row {
            width: parent.width; spacing: 14
            PanelBox {
                width: (parent.width - 14) / 2
                height: 300
                Column {
                    width: parent.width; spacing: 10
                    SectionTitle { text: "Dispositivos serie detectados · " + root.deviceList.length }
                    Repeater {
                        model: root.deviceList
                        delegate: RowItem {
                            required property int index
                            property var device: root.deviceList[index]
                            title: device.port
                            desc: (device.manufacturer || device.model ? ((device.manufacturer || "") + " " + (device.model || "")).trim() + " · " : "")
                                  + device.interface + " · velocidades habituales: " + device.rates.join(", ")
                            Text { text: device.connected ? "Conectado" : "Desconectado"; color: Theme.accentStrong; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    EmptyState {
                        visible: root.deviceList.length === 0
                        title: "No hay puertos serie visibles"
                        desc: "Conecta una placa USB. I²C, SPI, BLE y dispositivos de red requieren enumeración específica y no se infieren desde USB."
                    }
                }
            }
            PanelBox {
                width: (parent.width - 14) / 2
                height: 300
                Column {
                    width: parent.width; spacing: 10
                    SectionTitle { text: "Servicios locales" }
                    RowItem { title: "MQTT · localhost:1883"; desc: "Mosquitto u otro broker local · " + (root.current.mqttLocal ? "Activo" : "Detenido") }
                    RowItem { title: "Node-RED · localhost:1880"; desc: "Editor de flujos local · " + (root.current.nodeRedLocal ? "Activo" : "Detenido") }
                    RowItem { title: "Home Assistant · localhost:8123"; desc: "Instancia local · " + (root.current.homeAssistantLocal ? "Activo" : "No detectado") }
                    Text { text: "Se detecta conectividad TCP local; no se inicia ni configura ningún servicio."; color: Theme.c.textDim; font.pixelSize: 12; wrapMode: Text.WordWrap }
                }
            }
        }

        PanelBox {
            width: parent.width
            height: catalogColumn.implicitHeight + 40
            Column {
                id: catalogColumn
                width: parent.width; spacing: 10
                SectionTitle { text: "Catálogo · " + root.appList.length + " herramientas" }
                Repeater {
                    model: root.appList
                    delegate: RowItem {
                        required property int index
                        property var app: root.appList[index]
                        title: app.name
                        desc: app.function + " · " + app.compatibility
                        Text { text: app.installed ? "Disponible" : app.method === "apt" ? "APT · " + app.packages.join(", ") : "Método externo"; color: Theme.c.textDim; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
