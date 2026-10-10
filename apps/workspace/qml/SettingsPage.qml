import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ScrollView {
    id: settingsPage
    contentWidth: availableWidth
    ColumnLayout {
        width: settingsPage.availableWidth; spacing: 20
        Surface {
            Layout.fillWidth: true
            RowLayout {
                width: parent.width; spacing: 20
                Image {
                    Layout.preferredWidth: 64; Layout.preferredHeight: 64
                    source: "../../branding/logo.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Label { text: "DylanOS 1.0 Beta"; font.pixelSize: 24; font.weight: Font.DemiBold }
                    Label { text: backend.stats.host + " · " + backend.stats.kernel; font.pixelSize: 11; color: palette.placeholderText }
                }
                ActionButton { text: "Actualizar"; onClicked: backend.action("updates") }
            }
        }
        Label { text: "Apariencia"; font.pixelSize: 20; font.weight: Font.DemiBold }
        RowLayout {
            Layout.fillWidth: true; spacing: 14
            Repeater {
                model: [{name:"Oscuro", variant:"Dark", bg:"#23232d", panel:"#363644"}, {name:"Claro", variant:"Light", bg:"#eeeef4", panel:"#ffffff"}]
                delegate: Surface {
                    required property var modelData
                    Layout.fillWidth: true; padding: 16
                    ColumnLayout {
                        width: parent.width; spacing: 12
                        Rectangle {
                            Layout.fillWidth: true; height: 92; radius: 10; color: modelData.bg
                            Rectangle { x: 16; y: 16; width: parent.width - 32; height: 60; radius: 8; color: modelData.panel
                                Row { x: 10; y: 9; spacing: 5; Repeater { model: ["#ff5f57", "#febc2e", "#28c840"]; Rectangle { required property string modelData; width: 7; height: 7; radius: 4; color: modelData } } }
                            }
                        }
                        ActionButton { text: "Aplicar " + modelData.name.toLowerCase(); Layout.fillWidth: true; onClicked: { win.dark = modelData.variant === "Dark"; backend.theme(modelData.variant) } }
                    }
                }
            }
        }
        Label { text: "Preferencias del sistema"; font.pixelSize: 20; font.weight: Font.DemiBold }
        GridLayout {
            Layout.fillWidth: true; columns: 3; columnSpacing: 10; rowSpacing: 10
            Repeater {
                model: [{name:"Red e Internet", action:"network"}, {name:"Bluetooth", action:"bluetooth"}, {name:"Sonido", action:"audio"},
                        {name:"Pantallas", action:"display"}, {name:"Energía", action:"power"}, {name:"Teclado", action:"keyboard"},
                        {name:"Usuarios", action:"users"}, {name:"Escritorio", action:"appearance"}, {name:"Todos los ajustes", action:"settings"}]
                delegate: ActionButton { required property var modelData; text: modelData.name + "  ↗"; Layout.fillWidth: true; implicitHeight: 53; onClicked: backend.action(modelData.action) }
            }
        }
        Label { text: "Las preferencias se abren en los módulos nativos de KDE Plasma."; color: palette.placeholderText; font.pixelSize: 11 }
    }
}
