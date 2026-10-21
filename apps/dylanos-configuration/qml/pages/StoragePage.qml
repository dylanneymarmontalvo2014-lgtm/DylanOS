import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Almacenamiento: uso real del disco raíz y acciones de limpieza.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property var state: ({})

    function refresh() { state = System.storage() }
    Component.onCompleted: Qt.callLater(refresh)

    Column {
        id: col
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        Rectangle {
            width: parent.width
            height: 150
            radius: Theme.radiusCard
            color: Theme.c.surface
            border.width: 1
            border.color: Theme.c.border

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12
                // Los hijos de un Row no pueden usar anchors horizontales:
                // Item + dos Texts anclados mantiene el layout original.
                Item {
                    width: parent.width
                    height: freeText.implicitHeight
                    Text {
                        id: freeText
                        text: (root.state.freeGb || 0) + " GB disponibles"
                        font.pixelSize: 22
                        color: Theme.c.text
                    }
                    Text {
                        anchors.baseline: freeText.baseline
                        anchors.right: parent.right
                        text: (root.state.usedGb || 0) + " GB usados de " + (root.state.totalGb || 0) + " GB"
                        font.pixelSize: 13
                        color: Theme.c.textDim
                    }
                }
                Meter {
                    width: parent.width
                    pct: root.state.totalGb ? (root.state.usedGb / root.state.totalGb) * 100 : 0
                }
                Text {
                    text: (root.state.device || "/") + " · " + (root.state.filesystem || "")
                    font.pixelSize: 13
                    color: Theme.c.textDim
                }
            }
        }

        Text { text: "Discos"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                title: "Disco principal (/)"
                desc: (root.state.filesystem || "—") + " · " + (root.state.totalGb || 0) + " GB"
                last: true
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.state.totalGb ? Math.round((root.state.usedGb / root.state.totalGb) * 100) + "% usado" : "—"
                    font.pixelSize: 13
                    color: Theme.c.textDim
                }
            }
        }

        Text { text: "Limpieza"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "trash-2"
                title: "Vaciar la papelera"
                desc: "Elimina definitivamente el contenido de trash:/"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Limpiar"
                    onClicked: {
                        if (System.emptyTrash())
                            toast.show("Papelera vaciada")
                    }
                }
            }
            RowItem {
                width: parent.width
                icon: "package"
                title: "Paquetes antiguos (APT)"
                desc: "Requiere autorización del sistema (polkit)"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Limpiar"
                    onClicked: System.exec("pkexec", ["apt-get", "clean"])
                }
            }
        }
    }

    Toast { id: toast; anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 70 }
}
