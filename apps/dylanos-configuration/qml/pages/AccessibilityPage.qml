import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Accesibilidad: controles reales disponibles + módulo nativo completo.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        Text { text: "Visión"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                icon: "type"
                title: "Tamaño del texto"
                desc: "Escala de fuentes de todo el sistema"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir fuentes"
                    onClicked: System.openKcm(["kcm_fonts"])
                }
            }
            RowItem {
                width: parent.width
                icon: "contrast"
                title: "Contraste alto"
                desc: "Aplica un esquema de colores de alto contraste"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir colores"
                    onClicked: System.openKcm(["kcm_colors"])
                }
            }
            RowItem {
                width: parent.width
                icon: "eye"
                title: "Cursor grande"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir cursores"
                    onClicked: System.openKcm(["kcm_cursortheme"])
                }
            }
        }

        Text { text: "Movimiento y teclado"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                title: "Teclas especiales"
                desc: "Pulsa Mayús, Ctrl o Alt de una en una"
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir ajustes"
                    onClicked: System.openKcm(["kcm_access"])
                }
            }
            RowItem {
                width: parent.width
                title: "Reducir movimiento"
                desc: "Desactiva animaciones de la interfaz"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir ajustes"
                    onClicked: System.openKcm(["kcm_access"])
                }
            }
        }

        Text { text: "Audio"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            width: parent.width
            RowItem {
                width: parent.width
                title: "Lector de pantalla"
                desc: "Orca no está instalado en este sistema"
                last: true
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Pendiente"; font.pixelSize: 12; color: Theme.c.textDim }
            }
        }
    }
}
