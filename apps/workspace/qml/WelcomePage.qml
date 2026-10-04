import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ScrollView {
    id: page
    contentWidth: availableWidth
    ColumnLayout {
        width: page.availableWidth; spacing: 22
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 280; radius: 22; clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#442138" }
                GradientStop { position: 0.52; color: "#643143" }
                GradientStop { position: 1; color: "#253552" }
            }
            Rectangle { x: parent.width - 235; y: -190; width: 500; height: 500; radius: 250; rotation: -25; color: "transparent"; border.width: 45; border.color: "#17ffc4bf" }
            Rectangle { x: parent.width - 220; y: 85; width: 320; height: 320; radius: 160; color: "transparent"; border.width: 2; border.color: "#45ffc4bf" }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 30; spacing: 12
                Label { text: "BIENVENIDO A DYLANOS 1.0"; color: "#f3bdc8"; font.pixelSize: 10; font.letterSpacing: 2 }
                Label { text: "Todo empieza\ncon una idea."; color: "#fff6f8"; font.pixelSize: 42; font.weight: Font.DemiBold; font.letterSpacing: -1.7; lineHeight: 0.95 }
                Label { text: "Un escritorio tranquilo. Herramientas para ir más lejos."; color: "#e5cbd5"; font.pixelSize: 13 }
                Item { Layout.fillHeight: true }
                ActionButton { text: "Explorar mis archivos  →"; primary: true; onClicked: win.changePage("files") }
            }
        }
        RowLayout {
            Label { text: "Hazlo tuyo"; font.pixelSize: 21; font.weight: Font.DemiBold; font.letterSpacing: -0.5 }
            Item { Layout.fillWidth: true }
            Label { text: "LO ESENCIAL, A MANO"; color: palette.placeholderText; font.pixelSize: 9; font.letterSpacing: 1 }
        }
        GridLayout {
            Layout.fillWidth: true; columns: 3; columnSpacing: 14; rowSpacing: 14
            Repeater {
                model: [
                    {title:"Tu próximo proyecto", detail:"Python, web o C++.\nCrea algo que importe.", icon:"⌘", target:"dev", color:"#a496ee"},
                    {title:"Captura una idea", detail:"Notas locales y sencillas.\nSiempre a tu alcance.", icon:"▥", target:"notes", color:"#efc77d"},
                    {title:"Encuentra tu app", detail:"Software para trabajar,\ncrear y disfrutar.", icon:"⊞", target:"store", color:"#86c6c0"}
                ]
                delegate: Surface {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 230
                    ColumnLayout {
                        width: parent.width; spacing: 13
                        Label { text: modelData.icon; color: modelData.color; font.pixelSize: 30 }
                        Label { text: modelData.title; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Label { text: modelData.detail; font.pixelSize: 12; color: palette.placeholderText; lineHeight: 1.4 }
                        ActionButton { text: "Abrir  ↗"; Layout.topMargin: 5; onClicked: win.changePage(modelData.target) }
                    }
                }
            }
        }
        Surface {
            Layout.fillWidth: true; padding: 18
            RowLayout {
                width: parent.width; spacing: 14
                Label { text: "✦"; color: "#e98797"; font.pixelSize: 24 }
                ColumnLayout {
                    Layout.fillWidth: true
                    Label { text: "Un sistema que sigue mejorando"; font.weight: Font.DemiBold; font.pixelSize: 13 }
                    Label { text: "Revisa las actualizaciones de tus aplicaciones y del sistema."; color: palette.placeholderText; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
                }
                ActionButton { text: "Actualizaciones"; onClicked: backend.action("updates") }
            }
        }
    }
}
