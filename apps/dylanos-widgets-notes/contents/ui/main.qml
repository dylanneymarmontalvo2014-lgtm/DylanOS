pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Notas rápidas.
 *
 * Nota editable dentro del widget, persistida en la configuración del applet
 * (KConfig, por instancia). No escribe en /etc/skel ni en archivos
 * compartidos: cada widget guarda la suya en el perfil del usuario.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small, Tokens.mediumWide, Tokens.large]
    readonly property string defaultSize: Tokens.mediumWide
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    // Texto persistido. Vacío de fábrica: nada inventado. El respaldo evita
    // "Unable to assign [undefined] to QString" cuando la clave aún no existe.
    property string note: Plasmoid.configuration.note || ""

    function save(text) {
        Plasmoid.configuration.note = text;
    }

    fullRepresentation: Item {
        implicitWidth: root.width > 0 ? root.width
                                      : Tokens.widthFor(Tokens.mediumWide, root.cellSize)
        implicitHeight: root.cellSize

        WidgetShell {
            anchors.fill: parent
            title: "Nota"
            actionIcon: root.note.length > 0 ? "\u2715" : ""
            onActionClicked: {
                noteArea.text = "";
                root.save("");
            }

            Flickable {
                anchors.fill: parent
                contentHeight: noteArea.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: noteArea.implicitHeight > height

                TextEdit {
                    id: noteArea
                    width: parent.width
                    text: root.note
                    color: Tokens.white
                    selectionColor: Tokens.crimson
                    selectedTextColor: Tokens.white
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeBody
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    onTextChanged: root.save(text)

                    Text {
                        anchors.fill: parent
                        text: "Escribe una nota…"
                        color: Tokens.lightGray
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSizeBody
                        visible: noteArea.text.length === 0
                    }
                }
            }
        }
    }
}
