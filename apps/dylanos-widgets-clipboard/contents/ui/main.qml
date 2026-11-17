pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Portapapeles.
 *
 * LÍMITE DECLARADO: el historial de portapapeles requiere un backend
 * (klipper o cliphist). En la imagen actual no hay ninguno instalado, así que
 * este widget NO promete historial: muestra el contenido actual del
 * portapapeles y lo dice con claridad. Cuando se añada el backend, la lista
 * se rellena desde él sin cambiar el contrato del widget.
 *
 * Se lee con `xclip`/`wl-paste` si existen; si no, el widget lo indica.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small, Tokens.mediumWide]
    readonly property string defaultSize: Tokens.mediumWide
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell
    readonly property bool wide: width > height * 1.4

    preferredRepresentation: fullRepresentation

    // -1 = sin backend; 0 = backend disponible y portapapeles vacío.
    property int available: 0
    property string content: ""

    readonly property bool hasContent: root.content.length > 0

    Timer {
        id: poll
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    P5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            if (data.exitCode === 0) {
                root.available = 1;
                root.content = (data.stdout || "").trim();
            } else {
                // Ningún backend de portapapeles: se informa, no se simula.
                root.available = -1;
                root.content = "";
            }
        }
    }

    function refresh() {
        // wl-paste en Wayland, xclip en X11 (la sesión del ISO es X11).
        reader.connectSource(
            "sh -c 'if command -v wl-paste >/dev/null 2>&1; then wl-paste -n; "
            + "elif command -v xclip >/dev/null 2>&1; then xclip -selection clipboard -o; "
            + "else exit 127; fi'");
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(root.wide ? Tokens.mediumWide : Tokens.small,
                                       root.cellSize)
        implicitHeight: root.cellSize

        WidgetShell {
            anchors.fill: parent
            title: "Portapapeles"
            subtitle: root.available < 0 ? "Sin backend de portapapeles" : ""
            actionIcon: "\u21bb"
            onActionClicked: root.refresh()

            Text {
                anchors.fill: parent
                text: {
                    if (root.available < 0)
                        return "Instala xclip (X11) o wl-clipboard (Wayland) para leer el portapapeles. "
                             + "El historial requiere además klipper o cliphist.";
                    if (!root.hasContent)
                        return "El portapapeles está vacío.";
                    return root.content;
                }
                color: root.available < 0 ? Tokens.lightGray : Tokens.white
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSizeCaption
                wrapMode: Text.WrapAnywhere
                maximumLineCount: root.wide ? 4 : 6
                elide: Text.ElideRight
                clip: true
            }
        }
    }
}
