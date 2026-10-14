import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ScrollView {
    id: storePage
    contentWidth: availableWidth
    ColumnLayout {
        width: storePage.availableWidth; spacing: 22

        // ── Marca: logo DylanOS Store ─────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 18
            Image {
                source: "../assets/dylanos-store.png"; mipmap: true
                sourceSize.width: 64; sourceSize.height: 64
                Layout.preferredWidth: 64; Layout.preferredHeight: 64
                Accessible.role: Accessible.Graphic; Accessible.description: "DylanOS Store"
            }
            ColumnLayout {
                spacing: 3
                Label { text: "DylanOS Store"; font.pixelSize: 29; font.weight: Font.DemiBold; font.letterSpacing: -1 }
                Label { text: "Instala, actualiza y explora software para tu DylanOS."; color: palette.placeholderText }
            }
        }

        // ── Búsqueda ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Field { id: query; placeholderText: "Buscar aplicaciones, juegos y complementos…"; Layout.fillWidth: true; selectByMouse: true; onAccepted: backend.findSoftware(text) }
            ActionButton { text: "Buscar"; primary: true; onClicked: backend.findSoftware(query.text) }
            ActionButton { text: "Actualizaciones"; onClicked: backend.action("updates") }
        }

        // ── Banner destacado ──────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 190
            radius: 22
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#3a0d1e" }
                GradientStop { position: 0.55; color: "#220912" }
                GradientStop { position: 1.0; color: "#14050a" }
            }
            border.color: "#ff5274"; border.width: 1

            // Línea especular superior (liquid glass)
            Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1 } height: 1; color: "#30ffffff" }

            RowLayout {
                anchors.fill: parent; anchors.margins: 26; spacing: 20
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 10
                    Rectangle {
                        width:featuredLabel.implicitWidth + 18; height: 24; radius: 12
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0; color: "#e81740" }
                            GradientStop { position: 1; color: "#ad0a2a" }
                        }
                        border.color: "#ff5274"; border.width: 1
                        Label { id: featuredLabel; anchors.centerIn: parent; text: "Destacado de la semana"; color: "white"; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 1 }
                    }
                    Label { text: "Krita"; color: "white"; font.pixelSize: 26; font.weight: Font.DemiBold }
                    Label {
                        text: "Pinta, ilustra y retoca fotos con la suite de arte digital libre de DylanOS. Pinceles naturales, capas y soporte de tableta gráfica."
                        color: "#f2c9d3"; wrapMode: Text.Wrap; font.pixelSize: 13; Layout.fillWidth: true; Layout.maximumWidth: 520
                    }
                    RowLayout {
                        spacing: 10
                        ActionButton { text: "Obtener  ↗"; primary: true; onClicked: backend.findSoftware("krita") }
                        ActionButton { text: "Ver categoría"; onClicked: backend.findSoftware("diseño") }
                    }
                }
                Label { text: "✧"; color: "#ff2a54"; font.pixelSize: 92; font.weight: Font.DemiBold; Layout.rightMargin: 12 }
            }
        }

        // ── Promociones ────────────────────────────────────────────
        GridLayout {
            columns: storePage.availableWidth > 780 ? 2 : 1
            Layout.fillWidth: true; columnSpacing: 14; rowSpacing: 14
            Repeater {
                model: [
                    {name:"LibreOffice", detail:"Ofimática completa para documentos, hojas y presentaciones.", query:"libreoffice", symbol:"▤"},
                    {name:"VLC", detail:"Reproduce cualquier video, audio o transmisión sin complicaciones.", query:"vlc", symbol:"◉"}
                ]
                delegate: Surface {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 128
                    RowLayout {
                        width: parent.width; height: parent.height; spacing: 16
                        Label { text: modelData.symbol; color: "#DC143C"; font.pixelSize: 34; Layout.preferredWidth: 42 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Label { text: modelData.name; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Label { text: modelData.detail; color: palette.placeholderText; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        }
                        ActionButton { text: "Obtener"; onClicked: backend.findSoftware(modelData.query) }
                    }
                }
            }
        }

        // ── Categorías ─────────────────────────────────────────────
        Label { text: "Explora por categoría"; font.pixelSize: 20; font.weight: Font.DemiBold }
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

        // ── Populares ──────────────────────────────────────────────
        Label { text: "Populares de la comunidad"; font.pixelSize: 20; font.weight: Font.DemiBold }
        GridLayout {
            columns: storePage.availableWidth > 980 ? 3 : 2
            Layout.fillWidth: true; columnSpacing: 14; rowSpacing: 14
            Repeater {
                model: [
                    {name:"Firefox", tag:"Navegador web", query:"firefox-esr", symbol:"◉", color:"#e8927c"},
                    {name:"GIMP", tag:"Edición de imágenes", query:"gimp", symbol:"✧", color:"#d8adee"},
                    {name:"Inkscape", tag:"Diseño vectorial", query:"inkscape", symbol:"❖", color:"#8eafd9"},
                    {name:"Kdenlive", tag:"Edición de video", query:"kdenlive", symbol:"▤", color:"#eaa9b5"},
                    {name:"Elisa", tag:"Reproductor de música", query:"elisa", symbol:"♫", color:"#8bcdc2"},
                    {name:"VSCodium", tag:"Desarrollo", query:"codium", symbol:"⌘", color:"#f2c8a0"}
                ]
                delegate: Surface {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 250
                    ColumnLayout {
                        width: parent.width; spacing: 12
                        RowLayout {
                            spacing: 12
                            Label { text: modelData.symbol; color: modelData.color; font.pixelSize: 24; Layout.preferredWidth: 30 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label { text: modelData.name; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Label { text: modelData.tag; color: palette.placeholderText; font.pixelSize: 11 }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            ActionButton { text: "Instalar"; primary: true; onClicked: backend.findSoftware(modelData.query) }
                        }
                    }
                }
            }
        }

        // ── Confianza ──────────────────────────────────────────────
        Surface {
            Layout.fillWidth: true; padding: 26
            ColumnLayout {
                width: parent.width; spacing: 13
                Label { text: "Instalaciones seguras y controladas."; font.pixelSize: 23; font.weight: Font.DemiBold }
                Label { text: "DylanOS Store gestiona las descargas, los permisos y las actualizaciones de los repositorios configurados. Revisa los detalles antes de instalar."; wrapMode: Text.Wrap; Layout.fillWidth: true; color: palette.placeholderText; font.pixelSize: 13 }
                RowLayout {
                    spacing: 10
                    ActionButton { text: "Abrir catálogo completo  ↗"; onClicked: backend.action("store"); primary: true }
                    ActionButton { text: "Buscar actualizaciones"; onClicked: backend.action("updates") }
                }
            }
        }
    }
}
