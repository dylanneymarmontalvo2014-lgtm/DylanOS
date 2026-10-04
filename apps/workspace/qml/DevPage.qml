import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ScrollView {
    id: devPage
    contentWidth: availableWidth
    property string lastProject: ""
    Connections {
        target: backend
        function onProjectCreated(path) { devPage.lastProject = path }
    }
    ColumnLayout {
        width: devPage.availableWidth; spacing: 20
        Label { text: "De la idea al código."; font.pixelSize: 33; font.weight: Font.DemiBold; font.letterSpacing: -1 }
        Label { text: "Tu entorno de desarrollo, listo para empezar."; color: palette.placeholderText; Layout.bottomMargin: 6 }
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            ActionButton { text: "⌘  VSCodium"; primary: true; onClicked: backend.action("editor") }
            ActionButton { text: ">_  Terminal"; onClicked: backend.action("terminal") }
            ActionButton { text: "Instalar herramientas"; onClicked: backend.action("store") }
            Item { Layout.fillWidth: true }
            ActionButton { text: "Verificar"; onClicked: backend.scanTools() }
        }
        Surface {
            Layout.fillWidth: true
            ColumnLayout {
                width: parent.width; spacing: 15
                Label { text: "Crea tu próximo proyecto"; font.pixelSize: 19; font.weight: Font.DemiBold }
                Label { text: "Plantillas pequeñas, sin descargas ni dependencias ocultas."; font.pixelSize: 12; color: palette.placeholderText }
                RowLayout {
                    Layout.fillWidth: true
                    Field { id: projectName; placeholderText: "mi-proyecto"; Layout.fillWidth: true; selectByMouse: true; Accessible.name: "Nombre del proyecto" }
                    ComboBox { id: template; model: ["Python", "Web", "C++"]; Layout.preferredWidth: 140; Accessible.name: "Plantilla" }
                    ActionButton { text: backend.busy ? "Creando…" : "Crear proyecto"; primary: true; enabled: projectName.text.trim() !== "" && !backend.busy; onClicked: backend.createProject(parentFolder.text, projectName.text, template.currentText) }
                }
                Field { id: parentFolder; text: backend.projectsFolder; Layout.fillWidth: true; selectByMouse: true; Accessible.name: "Carpeta de proyectos" }
                RowLayout {
                    visible: devPage.lastProject !== ""; Layout.fillWidth: true
                    Label { text: "Creado: " + devPage.lastProject; color: "#70bb99"; elide: Text.ElideMiddle; Layout.fillWidth: true; font.pixelSize: 12 }
                    ActionButton { text: "Editar"; onClicked: backend.openProject(devPage.lastProject, "editor") }
                    ActionButton { text: "Terminal"; onClicked: backend.openProject(devPage.lastProject, "terminal") }
                    ActionButton { text: "Archivos"; onClicked: backend.openProject(devPage.lastProject, "files") }
                }
            }
        }
        Label { text: "Herramientas en este equipo"; font.pixelSize: 19; font.weight: Font.DemiBold }
        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: 12; rowSpacing: 10
            Repeater {
                model: backend.tools
                delegate: Surface {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 300; padding: 15
                    RowLayout {
                        width: parent.width
                        Rectangle { width: 7; height: 7; radius: 4; color: modelData.installed ? "#75c7a0" : "#c8a877" }
                        Label { text: modelData.name; font.weight: Font.DemiBold; Layout.preferredWidth: 80 }
                        Label { text: modelData.path; color: palette.placeholderText; font.pixelSize: 11; elide: Text.ElideLeft; Layout.fillWidth: true }
                    }
                }
            }
        }
        Label { text: "Consejo: usa un entorno virtual para Python y Podman para contenedores sin root."; color: palette.placeholderText; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
    }
}
