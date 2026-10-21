import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Pantalla: brillo real (powerdevil), resolución actual real (xrandr).
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    readonly property bool brightnessOk: System.brightnessAvailable
    property string currentMode: "—"

    function refresh() {
        const out = System.exec("xrandr", ["--current"])
        const star = /(\d+x\d+)\s+\d+\.\d+\*/.exec(out)
        currentMode = star ? star[1] : "—"
    }
    Component.onCompleted: Qt.callLater(refresh)

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        Text { text: "Brillo y color"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "sun"
                title: "Brillo"
                desc: root.brightnessOk ? "Pantalla integrada" : "No disponible en este equipo"
                DSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 260
                    enabled: root.brightnessOk
                    minimum: 0
                    maximum: System.maxBrightness || 100
                    value: System.brightness
                    onMoved: function (v) { System.brightness = v }
                }
            }
            RowItem {
                width: parent.width
                title: "Luz nocturna"
                desc: "Reduce la luz azul por la noche"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir ajustes"
                    onClicked: System.openKcm(["kcm_nightlight", "kcm_nightcolor"])
                }
            }
        }

        Text { text: "Monitor"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "monitor"
                title: "Resolución actual"
                desc: "Detectada del servidor gráfico"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentMode
                    font.pixelSize: 14
                    color: Theme.c.textDim
                }
            }
            RowItem {
                width: parent.width
                title: "Resolución, escala y orientación"
                desc: "Se ajustan en el módulo nativo de pantallas (KScreen)"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir pantalla"
                    onClicked: System.openKcm(["kcm_kscreen"])
                }
            }
            RowItem {
                width: parent.width
                title: "Frecuencia de actualización"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir pantalla"
                    onClicked: System.openKcm(["kcm_kscreen"])
                }
            }
        }
    }
}
