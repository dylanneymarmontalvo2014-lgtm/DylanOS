import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmoidItem.NoBackground
    compactRepresentation: dockContent
    fullRepresentation: dockContent

    // Nunca estirar: el dock mide exactamente lo que ocupan sus iconos.
    Layout.fillWidth: false
    Layout.fillHeight: false

    Layout.minimumWidth: dockRow.implicitWidth + (Plasmoid.configuration.dockPadding * 2)
    Layout.maximumWidth: Layout.minimumWidth
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: Plasmoid.configuration.hoverSize + 18
    Layout.preferredHeight: Layout.minimumHeight

    Behavior on Layout.minimumWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    TaskManager.TasksModel {
        id: tasksModel
        sortMode: TaskManager.TasksModel.SortVirtualDesktop
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: true
        filterByScreen: false
        filterNotMinimized: false

        // Apps fijadas por defecto. Ajustar/quitar segun lo que exista en DylanOS:
        //   find /usr/share/applications ~/.local/share/applications -iname "*dylanos*"
        launcherList: [
            "applications:dylanos-app-center.desktop",
            "applications:org.dylanos.calculator.desktop",
            "applications:org.kde.dolphin.desktop",
            "applications:org.kde.konsole.desktop",
            "applications:org.kde.kate.desktop",
            "applications:systemsettings.desktop"
        ]
    }

    Component {
        id: dockContent

        Item {
            implicitWidth: root.Layout.minimumWidth
            implicitHeight: root.Layout.minimumHeight

            Rectangle {
                id: dockBackground
                anchors.fill: parent
                radius: Plasmoid.configuration.cornerRadius
                color: "#0a0a0a"
                opacity: Plasmoid.configuration.backgroundOpacity

                Behavior on radius { NumberAnimation { duration: 150 } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: "#ffffff"
                    border.width: 1
                    opacity: 0.08
                }
            }

            Row {
                id: dockRow
                anchors.centerIn: parent
                spacing: Plasmoid.configuration.iconSpacing

                Repeater {
                    model: tasksModel

                    delegate: DockItemDelegate {
                        appIcon: model.decoration
                        appName: model.display !== undefined ? model.display : ""
                        isRunning: model.IsWindow === true
                        isPinned: model.IsLauncher === true

                        onClicked: {
                            var idx = tasksModel.makeModelIndex(index)
                            tasksModel.requestActivate(idx)
                        }

                        onTogglePin: {
                            var idx = tasksModel.makeModelIndex(index)
                            var url = tasksModel.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon)
                            if (isPinned) {
                                tasksModel.requestRemoveLauncher(url)
                            } else {
                                tasksModel.requestAddLauncher(url)
                            }
                        }
                    }
                }
            }
        }
    }
}
