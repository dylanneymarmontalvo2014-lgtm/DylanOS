import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ScrollView {
    id: storePage
    contentWidth: availableWidth
    ColumnLayout {
        width: storePage.availableWidth; spacing: 22
        Label { text: "Encuentra tu siguiente favorita."; font.pixelSize: 29; font.weight: Font.DemiBold; font.letterSpacing: -1 }
        Label { text: "Descubre e instala aplicaciones con KDE Discover."; color: palette.placeholderText }
        RowLayout {
            Layout.fillWidth: true
            Field { id: query; placeholderText: "Buscar software…"; Layout.fillWidth: true; selectByMouse: true; onAccepted: backend.findSoftware(text) }
            ActionButton { text: "Buscar"; primary: true; onClicked: backend.findSoftware(query.text) }
            ActionButton { text: "Actualizaciones"; onClicked: backend.action("updates") }
        }
        Surface {
            Layout.fillWidth: true; padding: 26
            ColumnLayout {
                width: parent.width; spacing: 13
                Label { text: "Un lugar para todo tu software."; font.pixelSize: 23; font.weight: Font.DemiBold }
                Label { text: "Discover gestiona las descargas, los permisos y las actualizaciones de los repositorios configurados. Revisa los detalles antes de instalar."; wrapMode: Text.Wrap; Layout.fillWidth: true; color: palette.placeholderText; font.pixelSize: 13 }
                ActionButton { text: "Abrir catálogo completo  ↗"; onClicked: backend.action("store"); primary: true }
            }
        }
        Label { text: "Explora por actividad"; font.pixelSize: 20; font.weight: Font.DemiBold }
        GridLayout {
            columns: 2; Layout.fillWidth: true; columnSpacing: 14; rowSpacing: 14
            Repeater {
                model: [
                    {name:"Crear y diseñar", detail:"GIMP · Inkscape · Krita", query:"krita", symbol:"✧", color:"#d8adee"},
                    {name:"Trabajar y estudiar", detail:"LibreOffice · Okular", query:"libreoffice", symbol:"▤", color:"#8eafd9"},
                    {name:"Programar", detail:"Editores y herramientas", query:"development", symbol:"⌘", color:"#eaa9b5"},
                    {name:"Escuchar y mirar", detail:"VLC · Elisa", query:"elisa", symbol:"♫", color:"#8bcdc2"}
                ]
                delegate: Surface {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 330
                    RowLayout {
                        width: parent.width; spacing: 15
                        Label { text: modelData.symbol; color: modelData.color; font.pixelSize: 31; Layout.preferredWidth: 40 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: modelData.name; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Label { text: modelData.detail; color: palette.placeholderText; font.pixelSize: 11 }
                        }
                        ActionButton { text: "Ver"; onClicked: backend.findSoftware(modelData.query) }
                    }
                }
            }
        }
    }
}
