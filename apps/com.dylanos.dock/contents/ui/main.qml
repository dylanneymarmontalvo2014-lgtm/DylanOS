import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    compactRepresentation: dockContent
    fullRepresentation: dockContent

    // Nunca estirar: el dock mide exactamente lo que ocupan sus iconos.
    Layout.fillWidth: false
    Layout.fillHeight: false

    // dockRow vive dentro de `dockContent` (un Component) y no existe en el
    // ámbito QML del applet. Derivar el ancho de las entradas del modelo evita
    // ReferenceError y da al panel espacio para mostrar los iconos fijados.
    // Las opciones del usuario permiten cambiar ambos tamaños por separado.
    // Reservar siempre el tamaño mayor para que iconSize > hoverSize no recorte
    // iconos ni haga que los delegados se solapen en configuraciones extremas.
    readonly property int effectiveIconExtent: Math.max(Plasmoid.configuration.iconSize,
                                                         Plasmoid.configuration.hoverSize)
    readonly property int dockRowWidth: Math.max(1, tasksModel.count) * (effectiveIconExtent + 8)
        + Math.max(0, tasksModel.count - 1) * Plasmoid.configuration.iconSpacing

    Layout.minimumWidth: dockRowWidth + (Plasmoid.configuration.dockPadding * 2)
    Layout.maximumWidth: Layout.minimumWidth
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: effectiveIconExtent + 18
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
            "applications:org.dylanos.explorer.desktop",
            "applications:org.dylanos.browser.desktop",
            "applications:com.microsoft.VSCode.desktop",
            "applications:dylanos-app-center.desktop",
            "applications:org.dylanos.store.desktop",
            "applications:org.dylanos.configuration.desktop",
            "applications:org.dylanos.calculator.desktop"
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
                color: "#0a080b"
                antialiasing: true
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(68 / 255, 28 / 255, 42 / 255,
                            Math.min(0.76, Plasmoid.configuration.backgroundOpacity + 0.18))
                    }
                    GradientStop {
                        position: 0.42
                        color: Qt.rgba(24 / 255, 18 / 255, 25 / 255,
                            Math.min(0.92, Plasmoid.configuration.backgroundOpacity + 0.27))
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(8 / 255, 8 / 255, 11 / 255,
                            Math.min(0.94, Plasmoid.configuration.backgroundOpacity + 0.30))
                    }
                }

                Behavior on radius { NumberAnimation { duration: 150 } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: "#66f4dce5"
                    border.width: 1
                }

                // Reflejo de cristal en la parte alta: se dibuja con gradiente,
                // sin blur por software ni efectos costosos por fotograma.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 1
                    height: Math.max(0, parent.height * 0.62)
                    radius: Math.max(0, parent.radius - 1)
                    clip: true
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#20ffffff" }
                        GradientStop { position: 0.42; color: "#0affd9e3" }
                        GradientStop { position: 1; color: "#00ffffff" }
                    }
                }

                // Línea especular carmesí: da profundidad sin animar blur ni
                // sombras costosas durante la ampliación de los iconos.
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(0, parent.width - parent.radius * 1.5)
                    height: 1
                    radius: 1
                    color: "#ff5274"
                    opacity: 0.48
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(0, parent.width - parent.radius * 1.5)
                    height: 1
                    radius: 1
                    color: "#dc143c"
                    opacity: 0.18
                }
            }

            Row {
                id: dockRow
                anchors.centerIn: parent
                spacing: Plasmoid.configuration.iconSpacing
                property int hoverIndex: -1

                Repeater {
                    model: tasksModel

                    delegate: DockItemDelegate {
                        dockRoot: dockRow
                        delegateIndex: index
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
