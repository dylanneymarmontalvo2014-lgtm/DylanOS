pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens
import "lib/WidgetData.js" as Data

/*
 * DylanOS Widgets — Próximo evento.
 *
 * LÍMITE DECLARADO: la imagen no incluye Akonadi ni KOrganizer, así que no
 * hay calendario de sistema que leer. Este widget lee un archivo .ics LOCAL
 * que el usuario elige en la configuración del applet y muestra el próximo
 * evento futuro real. Sin archivo, lo dice; nunca inventa un evento.
 *
 * El análisis de iCalendar está en lib/WidgetData.js (parseNextEvent) y se
 * verifica con `node` en scripts/tests/test_widgets.py.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small, Tokens.mediumWide]
    readonly property string defaultSize: Tokens.mediumWide
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell
    readonly property bool wide: width > height * 1.4

    preferredRepresentation: fullRepresentation

    property string icsPath: Plasmoid.configuration.icsPath || ""
    property string eventTitle: ""
    property string eventWhen: ""
    property bool hasEvent: false
    property bool pathMissing: false

    readonly property date now: nowTimer.date

    Timer {
        id: nowTimer
        property date date: new Date()
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            date = new Date();
            root.reload();
        }
    }

    P5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            if (data.exitCode !== 0) {
                root.pathMissing = true;
                root.hasEvent = false;
                return;
            }
            root.pathMissing = false;
            root.applyIcs(data.stdout || "");
        }
    }

    function reload() {
        if (root.icsPath.length === 0) {
            root.hasEvent = false;
            return;
        }
        // Se cita la ruta: el usuario puede tener espacios en el nombre.
        reader.connectSource("cat " + root.quote(root.icsPath));
    }

    function quote(path) {
        return "'" + String(path).replace(/'/g, "'\\''") + "'";
    }

    function applyIcs(text) {
        const event = Data.parseNextEvent(text, root.now.getTime());
        if (!event) {
            root.hasEvent = false;
            root.eventTitle = "";
            root.eventWhen = "";
            return;
        }
        root.hasEvent = true;
        root.eventTitle = event.title.length > 0 ? event.title : "Evento sin título";
        root.eventWhen = Qt.formatDateTime(new Date(event.startMs), "ddd d MMM · HH:mm");
    }

    Component.onCompleted: reload()

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(root.wide ? Tokens.mediumWide : Tokens.small,
                                       root.cellSize)
        implicitHeight: root.cellSize

        WidgetShell {
            anchors.fill: parent
            title: "Próximo evento"
            subtitle: root.icsPath.length > 0 ? "" : "Sin calendario configurado"

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Tokens.space1

                Text {
                    width: parent.width
                    text: {
                        if (root.icsPath.length === 0)
                            return "Elige un archivo .ics en la configuración del widget.";
                        if (root.pathMissing)
                            return "No se pudo leer el archivo .ics.";
                        if (!root.hasEvent)
                            return "No hay eventos futuros en el calendario.";
                        return root.eventTitle;
                    }
                    color: root.hasEvent ? Tokens.white : Tokens.lightGray
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeBody
                    font.weight: root.hasEvent ? Font.DemiBold : Font.Normal
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.hasEvent
                    text: root.eventWhen
                    color: Tokens.crimson
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeCaption
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
