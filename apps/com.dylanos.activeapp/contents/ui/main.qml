import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    // El applet toma el espacio libre del panel y solo recorta cuando no
    // queda sitio: un tope fijo (200/400 px) cortaba nombres reales aunque
    // sobrara panel; el elidrado es el último recurso, no el primero.
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumWidth: 24
    Layout.maximumWidth: 4096
    Layout.preferredWidth: Math.min(contentRow.implicitWidth + 16, 4096)

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
                Layout.fillWidth: true
                Layout.minimumWidth: 16
                elide: Text.ElideRight
            }
        }
    }
}
