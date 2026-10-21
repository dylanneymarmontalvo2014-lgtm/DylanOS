import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Hora e idioma: zona horaria y NTP reales (timedatectl), idioma nativo.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property var state: ({})
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
    Component.onCompleted: state = System.dateTime()

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

            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 24
                spacing: 4
                Text {
                    text: Qt.formatTime(root.now, "hh:mm:ss ap")
                    font.pixelSize: 34
                    font.weight: Font.Light
                    color: Theme.c.text
                }
                Text {
                    text: Qt.formatDate(root.now, "dddd, d 'de' MMMM 'de' yyyy")
                    font.pixelSize: 14
                    font.capitalization: Font.Capitalize
                    color: Theme.c.textDim
                }
            }
        }

        Text { text: "Fecha y hora"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "clock"
                title: "Establecer la hora automáticamente"
                desc: "Protocolo NTP (requiere autorización del sistema)"
                DToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.state.ntp === true
                    onToggled: function (v) {
                        System.setNtp(v)
                        root.state = System.dateTime()
                    }
                }
            }
            RowItem {
                width: parent.width
                title: "Zona horaria"
                desc: root.state.timezone || "—"
                DSelect {
                    anchors.verticalCenter: parent.verticalCenter
                    menuWidth: 300
                    value: root.state.timezone || "—"
                    options: ["America/Bogota", "America/Mexico_City", "America/Argentina/Buenos_Aires", "Europe/Madrid", "UTC"]
                    onPicked: function (v) {
                        System.setTimezone(v)
                        root.state = System.dateTime()
                    }
                }
            }
            RowItem {
                width: parent.width
                title: "Formato de hora"
                desc: "Se toma de la configuración regional del sistema"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir formato"
                    onClicked: System.openKcm(["kcm_regionandlang", "kcm_locale"])
                }
            }
        }

        Text { text: "Idioma y región"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "languages"
                title: "Idioma de la interfaz"
                desc: "Idioma y formatos regionales del sistema"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir idioma"
                    onClicked: System.openKcm(["kcm_regionandlang", "kcm_locale"])
                }
            }
            RowItem {
                width: parent.width
                icon: "keyboard"
                title: "Distribución del teclado"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir teclado"
                    onClicked: System.openKcm(["kcm_keyboard"])
                }
            }
        }
    }
}
