// Pestaña Aplicaciones: procesos agrupados por aplicación real.
//
// "Cerrar" pide confirmación y luego envía SIGTERM a todos los procesos de la
// app, informando el resultado real del kernel.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import org.dylanos.process

Item {
    id: page

    property int pendingClose: -1
    property string pendingName: ""

    function requestClose(row, name) {
        pendingClose = row
        pendingName = name
    }

    function confirmClose() {
        if (pendingClose < 0)
            return
        const pids = applicationModel.pidsAt(pendingClose)
        pendingClose = -1
        let done = 0
        let failed = 0
        for (let i = 0; i < pids.length; ++i) {
            if (processController.terminateProcess(pids[i]))
                done += 1
            else
                failed += 1
        }
        if (failed > 0)
            root.showToast(qsTr("%1 procesos cerrados, %2 rechazados por el sistema")
                           .arg(done).arg(failed), false)
        else if (done > 0)
            root.showToast(qsTr("%1 procesos cerrados").arg(done), true)
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Item {
            width: parent.width
            implicitHeight: grid.implicitHeight + 36

            GridLayout {
                id: grid
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 18
                columns: Math.max(1, Math.floor(width / 242))
                columnSpacing: 14
                rowSpacing: 14

                Repeater {
                    model: applicationModel

                    delegate: Rectangle {
                        id: appCard
                        required property int index
                        required property string name
                        required property string icon
                        required property string iconPath
                        required property real cpu
                        required property real rss
                        required property int processCount
                        required property string state

                        Layout.fillWidth: true
                        implicitHeight: 132
                        radius: Theme.panelRadius
                        color: Theme.surfaceElevated
                        border.width: 1
                        border.color: cardHover.hovered ? Theme.borderStrong : Theme.border

                        HoverHandler {
                            id: cardHover
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 11

                                ProcessIcon {
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 38
                                    radius: 10
                                    iconName: appCard.icon
                                    iconPath: appCard.iconPath
                                    fallbackText: appCard.name.length > 0
                                                  ? appCard.name.charAt(0).toUpperCase() : "?"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: appCard.name
                                        color: Theme.textPrimary
                                        font.family: Theme.uiFont
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: appCard.processCount > 1
                                              ? qsTr("%1 · %2 procesos").arg(appCard.state)
                                                    .arg(appCard.processCount)
                                              : appCard.state
                                        color: Theme.textTertiary
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: Format.bytes(appCard.rss)
                                    color: Theme.textSecondary
                                    font.family: Theme.monoFont
                                    font.pixelSize: 12
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: Format.percent(appCard.cpu) + " CPU"
                                    color: Theme.textSecondary
                                    font.family: Theme.monoFont
                                    font.pixelSize: 12
                                }
                            }

                            Item { Layout.fillHeight: true }

                            ActionButton {
                                Layout.fillWidth: true
                                implicitHeight: 30
                                label: qsTr("Cerrar")
                                danger: true
                                onClicked: page.requestClose(appCard.index, appCard.name)
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: applicationModel.count === 0
                width: parent.width - 48
                text: qsTr("No hay aplicaciones en ejecución con icono propio en el sistema.")
                color: Theme.textTertiary
                font.family: Theme.uiFont
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Confirmación obligatoria antes de cerrar una app.
    Rectangle {
        anchors.fill: parent
        visible: page.pendingClose >= 0
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
                    text: qsTr("¿Cerrar %1?").arg(page.pendingName)
                    color: Theme.textPrimary
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: qsTr("Se enviará SIGTERM a todos los procesos de la aplicación. Los cambios sin guardar se perderán.")
                    color: Theme.textSecondary
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    lineHeight: 1.45
                }

                Row {
                    spacing: 8

                    ActionButton {
                        width: 180
                        implicitHeight: 32
                        label: qsTr("Cancelar")
                        onClicked: page.pendingClose = -1
                    }

                    ActionButton {
                        width: 180
                        implicitHeight: 32
                        label: qsTr("Cerrar aplicación")
                        solid: true
                        onClicked: page.confirmClose()
                    }
                }
            }
        }
    }
}
