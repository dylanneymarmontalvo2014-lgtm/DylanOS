pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Tareas.
 *
 * Lista de tareas con estado hecho/pendiente, persistida como JSON en la
 * configuración del applet. Empieza vacía: no hay tareas de ejemplo.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small, Tokens.mediumWide, Tokens.large]
    readonly property string defaultSize: Tokens.mediumWide
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    property string serialized: Plasmoid.configuration.tasks || "[]"
    property var tasks: root.parse(root.serialized)

    readonly property int pendingCount: tasks.filter(t => !t.d).length

    function parse(raw) {
        try {
            const value = JSON.parse(raw || "[]");
            return Array.isArray(value) ? value : [];
        } catch (error) {
            // Una configuración corrupta no debe romper el widget.
            return [];
        }
    }

    function persist(list) {
        root.tasks = list;
        Plasmoid.configuration.tasks = JSON.stringify(list);
    }

    function addTask(text) {
        const trimmed = String(text || "").trim();
        if (trimmed.length === 0)
            return;
        const list = root.tasks.slice();
        list.push({ "t": trimmed, "d": false });
        root.persist(list);
    }

    function toggle(index) {
        const list = root.tasks.slice();
        if (index < 0 || index >= list.length)
            return;
        list[index] = { "t": list[index].t, "d": !list[index].d };
        root.persist(list);
    }

    function removeTask(index) {
        const list = root.tasks.slice();
        if (index < 0 || index >= list.length)
            return;
        list.splice(index, 1);
        root.persist(list);
    }

    fullRepresentation: Item {
        implicitWidth: root.width > 0 ? root.width
                                      : Tokens.widthFor(Tokens.mediumWide, root.cellSize)
        implicitHeight: root.cellSize

        WidgetShell {
            anchors.fill: parent
            title: "Tareas"
            subtitle: root.pendingCount > 0
                      ? root.pendingCount + (root.pendingCount === 1 ? " pendiente"
                                                                    : " pendientes")
                      : ""

            Column {
                anchors.fill: parent
                spacing: Tokens.space1

                Rectangle {
                    width: parent.width
                    height: Tokens.space5
                    radius: Tokens.radiusControl
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: newTask.activeFocus ? Tokens.crimson
                                                      : Qt.rgba(1, 1, 1, 0.10)

                    TextInput {
                        id: newTask
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.space2
                        anchors.rightMargin: Tokens.space2
                        verticalAlignment: TextInput.AlignVCenter
                        color: PlasmaCore.Theme.textColor
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSizeCaption
                        selectionColor: Tokens.crimson
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Nueva tarea y Enter…"
                            color: PlasmaCore.Theme.disabledTextColor
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSizeCaption
                            visible: newTask.text.length === 0
                        }

                        Keys.onReturnPressed: {
                            root.addTask(text);
                            text = "";
                        }
                    }
                }

                ListView {
                    width: parent.width
                    height: parent.height - Tokens.space5 - Tokens.space1
                    clip: true
                    model: root.tasks
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: taskRow
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: Tokens.space5

                        Text {
                            id: taskLabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Tokens.space6
                            text: taskRow.modelData.t
                            color: taskRow.modelData.d ? PlasmaCore.Theme.disabledTextColor : PlasmaCore.Theme.textColor
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSizeCaption
                            font.strikeout: taskRow.modelData.d
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: taskLabel
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggle(taskRow.index)
                        }

                        Item {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Tokens.space4
                            height: Tokens.space4

                            Text {
                                anchors.centerIn: parent
                                text: "\u2715"
                                color: removeArea.containsMouse ? Tokens.crimson
                                                                : PlasmaCore.Theme.disabledTextColor
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontSizeCaption
                            }

                            MouseArea {
                                id: removeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeTask(taskRow.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
