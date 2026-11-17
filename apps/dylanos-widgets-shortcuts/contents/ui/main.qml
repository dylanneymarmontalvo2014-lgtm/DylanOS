pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Accesos directos.
 *
 * Lanza aplicaciones reales del sistema. El lanzamiento lee el campo Exec del
 * .desktop y lo ejecuta como argv, sin pasar por un shell: es el mismo
 * criterio que Spotlight (exec_utils.desktop_exec_argv), que evita que los
 * metacaracteres de un Exec se interpreten como código.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small, Tokens.mediumWide]
    readonly property string defaultSize: Tokens.small
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell
    readonly property bool wide: width > height * 1.4

    preferredRepresentation: fullRepresentation

    // Aplicaciones fijadas; el usuario puede cambiarlas por configuración.
    // Se lee con respaldo porque una configuración ausente (primer arranque o
    // entrada nueva) no debe producir "Unable to assign [undefined] to QString".
    property string pinned: Plasmoid.configuration.pinned || ""

    readonly property var apps: root.parsePinned(root.pinned)

    function parsePinned(raw) {
        try {
            const value = JSON.parse(raw || "[]");
            return Array.isArray(value) ? value : [];
        } catch (error) {
            return [];
        }
    }

    function defaults() {
        return [
            { "name": "Explorer", "icon": "system-file-manager", "id": "org.dylanos.explorer.desktop" },
            { "name": "Navegador", "icon": "web-browser", "id": "org.dylanos.browser.desktop" },
            { "name": "Tienda", "icon": "store", "id": "org.dylanos.store.desktop" },
            { "name": "Terminal", "icon": "utilities-terminal", "id": "org.dylanos.console.desktop" }
        ];
    }

    readonly property var shown: apps.length > 0 ? apps : defaults()

    // gtk-launch resuelve el .desktop y ejecuta su Exec como argv, sin shell.
    // Está presente en el perfil (libgtk-3/4-bin lo instalan).
    P5Support.DataSource {
        id: launcher
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => disconnectSource(sourceName)
    }

    function launch(desktopId) {
        launcher.connectSource("gtk-launch " + desktopId);
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(root.wide ? Tokens.mediumWide : Tokens.small,
                                       root.cellSize)
        implicitHeight: root.cellSize

        WidgetShell {
            anchors.fill: parent
            title: "Accesos"

            Grid {
                anchors.centerIn: parent
                columns: root.wide ? 4 : 2
                spacing: Tokens.space2

                Repeater {
                    model: root.shown

                    delegate: Item {
                        id: tile
                        required property var modelData
                        width: Tokens.space6
                        height: Tokens.space6

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radiusControl
                            color: tileArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                                                          : Qt.rgba(1, 1, 1, 0.04)

                            // Icono real del tema: las iniciales se repetían
                            // (Explorer/Tienda/Terminal daban E, T, T) y dos
                            // accesos resultaban indistinguibles.
                            Kirigami.Icon {
                                id: iconImage
                                anchors.centerIn: parent
                                width: Tokens.space4
                                height: Tokens.space4
                                source: tile.modelData.icon
                                isMask: false
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: iconImage.status !== Kirigami.Icon.Ready
                                // Respaldo con las dos primeras letras del
                                // nombre: una sola inicial repetía «E, T, T» y
                                // dos accesos quedaban indistinguibles.
                                text: tile.modelData.name.substr(0, 2).toUpperCase()
                                color: Tokens.white
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontSizeCaption
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: tileArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launch(tile.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
