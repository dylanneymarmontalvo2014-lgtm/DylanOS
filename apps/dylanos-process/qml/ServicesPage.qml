// Pestaña Servicios: unidades reales de systemd con inicio/parada reales.
//
// El estado que se pinta viene de `systemctl list-units`; una acción solo se
// muestra como conseguida cuando systemd devuelve éxito. Si systemd rechaza la
// operación (polkit, permisos), se muestra su mensaje tal cual.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import org.dylanos.process

Item {
    id: page

    property int pendingRow: -1
    property bool pendingStart: false
    property string pendingName: ""

    Component.onCompleted: serviceModel.reload()

    // QA: si el entorno no tiene systemd (contenedor, chroot de pruebas), la
    // lista sale vacía y con un mensaje honesto; los tests inyectan unidades
    // con setTestUnits para comprobar la interfaz de la pestaña. En una sesión
    // real nunca se inyecta nada.
    function setTestUnits(units) {
        serviceModel.setTestUnits(units)
    }

    function clearTestUnits() {
        serviceModel.clearTestUnits()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Cabecera con recarga real de la lista.
        Item {
            Layout.fillWidth: true
            implicitHeight: 48

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.border
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Text {
                    text: qsTr("%1 unidades de servicio").arg(serviceModel.count)
                    color: Theme.textTertiary
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                Item { Layout.fillWidth: true }

                ActionButton {
                    implicitWidth: 150
                    implicitHeight: 30
                    label: qsTr("Recargar lista")
                    onClicked: serviceModel.reload()
                }
            }
        }

        ListView {
            id: list
            objectName: "servicesList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: serviceModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                active: true
            }

            delegate: Rectangle {
                required property int index
                required property string name
                required property string description
                required property bool active
                required property string scope
                required property string stateLabel

                width: list.width
                height: 62
                color: rowHover.hovered ? "#0affffff" : "transparent"

                HoverHandler {
                    id: rowHover
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.borderSubtle
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: Theme.controlRadius
                        color: Theme.surfaceElevated
                        border.width: 1
                        border.color: Theme.border

                        Image {
                            anchors.centerIn: parent
                            source: "image://icon/system-run-symbolic"
                            sourceSize.width: 15
                            sourceSize.height: 15
                            visible: status === Image.Ready
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 8

                            Text {
                                text: parent.parent.parent.name
                                color: Theme.textPrimary
                                font.family: Theme.monoFont
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                Layout.maximumWidth: 420
                            }

                            Text {
                                text: parent.parent.parent.scope
                                color: Theme.textTertiary
                                font.family: Theme.uiFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                padding: 0
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: parent.parent.parent.description.length > 0
                                  ? parent.parent.parent.description : qsTr("Sin descripción")
                            color: Theme.textTertiary
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    StateBadge {
                        Layout.preferredWidth: 84
                        Layout.alignment: Qt.AlignVCenter
                        text: parent.stateLabel
                        dotColor: parent.active ? Theme.success : Theme.textTertiary
                        centered: true
                    }

                    ActionButton {
                        Layout.preferredWidth: 90
                        implicitHeight: 28
                        label: parent.active ? qsTr("Detener") : qsTr("Iniciar")
                        danger: parent.active
                        onClicked: page.requestToggle(parent.index, parent.name, !parent.active)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: serviceModel.count === 0
                width: parent.width - 48
                text: serviceModel.available
                      ? qsTr("No hay unidades de servicio que mostrar.")
                      : serviceModel.errorText
                color: Theme.textTertiary
                font.family: Theme.uiFont
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Confirmación antes de parar un servicio; iniciar no necesita diálogo.
    Rectangle {
        anchors.fill: parent
        visible: page.pendingRow >= 0
        color: "#a6000000"

        Rectangle {
            anchors.centerIn: parent
            width: 420
            implicitHeight: dialogColumn.implicitHeight + 40
            radius: Theme.panelRadius
            color: Theme.windowColor
            border.width: 1
            border.color: Theme.borderStrong

            Column {
                id: dialogColumn
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                Text {
                    width: parent.width
                    text: page.pendingStart ? qsTr("¿Iniciar %1?").arg(page.pendingName)
                                            : qsTr("¿Detener %1?").arg(page.pendingName)
                    color: Theme.textPrimary
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: page.pendingStart
                          ? qsTr("Se pedirá autorización a polkit si la unidad lo requiere.")
                          : qsTr("La unidad se detendrá ahora. No se cambia su estado al arrancar.")
                    color: Theme.textSecondary
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    lineHeight: 1.45
                }

                Row {
                    spacing: 8

                    ActionButton {
                        width: 180
                        implicitHeight: 32
                        label: qsTr("Cancelar")
                        onClicked: page.pendingRow = -1
                    }

                    ActionButton {
                        width: 180
                        implicitHeight: 32
                        label: page.pendingStart ? qsTr("Iniciar") : qsTr("Detener")
                        solid: page.pendingStart
                        danger: !page.pendingStart
                        onClicked: {
                            const row = page.pendingRow
                            const start = page.pendingStart
                            page.pendingRow = -1
                            if (row >= 0)
                                serviceModel.setActive(row, start)
                        }
                    }
                }
            }
        }
    }

    function requestToggle(row, name, start) {
        pendingRow = row
        pendingName = name
        pendingStart = start
    }
}
