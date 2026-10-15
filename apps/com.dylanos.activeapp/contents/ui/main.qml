import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    // 400 px cubre los nombres de aplicación reales más largos sin que un
    // título patológico consuma todo el panel; antes con 200 px el nombre
    // de la app activa salía cortado con puntos suspensivos.
    readonly property int maxTitleWidth: 400

    Layout.fillWidth: false
    Layout.fillHeight: true
    Layout.preferredWidth: Math.min(contentRow.implicitWidth + 16, maxTitleWidth + 16)
    // El applet nunca debe colapsar por debajo de lo que pide el título: con
    // el mínimo anterior (16 px) el panel podía encogerlo hasta mostrar solo
    // una letra del nombre de la aplicación activa.
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: maxTitleWidth + 16

    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {
        id: container
        implicitWidth: contentRow.implicitWidth + 16
        implicitHeight: parent ? parent.height : 30
        // El título nunca se pinta fuera del applet mientras el panel
        // redimensiona: sin esto el texto se cruza con el menú de la app.
        clip: true

        TaskManager.TasksModel {
            id: tasksModel
            filterByScreen: false
            filterByVirtualDesktop: false
            filterNotMinimized: false
        }

        RowLayout {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 0

            Text {
                id: titleLabel
                text: {
                    for (var i = 0; i < tasksModel.count; ++i) {
                        var idx = tasksModel.makeModelIndex(i)
                        if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive) === true) {
                            var appName = tasksModel.data(idx, TaskManager.AbstractTasksModel.AppName)
                            if (appName && appName.length > 0) return appName
                            var display = tasksModel.data(idx, Qt.DisplayRole)
                            if (display && display.length > 0) {
                                var parts = display.split(" — ")
                                return parts.length > 1 ? parts[parts.length - 1] : display.split(" - ")[0]
                            }
                        }
                    }
                    return "DylanOS"
                }
                font.bold: true
                font.pixelSize: 13
                font.family: "Inter"
                color: "#ffffff"
                verticalAlignment: Text.AlignVCenter
                Layout.maximumWidth: root.maxTitleWidth
                elide: Text.ElideRight
            }
        }
    }
}
