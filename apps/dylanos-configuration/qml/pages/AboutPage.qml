import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Acerca de DylanOS: información real del sistema.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property var info: System.sysInfo()

    Component.onCompleted: info = System.sysInfo()

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        Rectangle {
            width: parent.width
            height: 140
            radius: Theme.radiusCard
            color: Theme.c.surface
            border.width: 1
            border.color: Theme.c.border

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 24
                spacing: 24
                Image {
                    source: "qrc:/assets/logo.png"
                    width: 96
                    height: 96
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
                Row {
                    spacing: 10
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "DylanOS Crimson"; font.pixelSize: 24; color: Theme.c.text }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: root.info.version || "1.0 Beta"; font.pixelSize: 14; color: Theme.c.textDim }
                    BadgePill { anchors.verticalCenter: parent.verticalCenter; text: "Estable" }
                }
            }
        }

        Text { text: "Especificaciones"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            Repeater {
                model: [
                    { k: "Distribución", v: root.info.distro || "DylanOS" },
                    { k: "Versión", v: root.info.version || "—" },
                    { k: "Sistema base", v: root.info.base || "Debian" },
                    { k: "Entorno de escritorio", v: "KDE Plasma" },
                    { k: "Núcleo", v: root.info.kernel || "—" },
                    { k: "Arquitectura", v: root.info.arch || "—" },
                    { k: "Procesador", v: root.info.cpu || "—" },
                    { k: "Memoria RAM", v: root.info.memoryGb || "—" },
                    { k: "Equipo", v: root.info.device || root.info.hostname || "—" }
                ]
                delegate: RowItem {
                    required property var modelData
                    required property int index
                    width: parent.width
                    title: modelData.k
                    last: index === 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.v
                        font.pixelSize: 14
                        color: Theme.c.textDim
                    }
                }
            }
        }

        Text {
            text: "Datos leídos del sistema real (/proc, /sys, os-release)."
            font.pixelSize: 12
            color: Theme.c.textDim
        }
    }
}
