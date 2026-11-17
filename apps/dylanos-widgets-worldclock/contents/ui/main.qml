pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Reloj mundial.
 *
 * Varias zonas horarias reales, resueltas con `date` del sistema.
 *
 * Por qué no se usa el motor JS: el motor QML NO incluye Intl (verificado,
 * `typeof Intl` es "undefined") y TZInfo tampoco está en todos los Qt
 * (verificado: "TZInfo is not defined"). Con cualquiera de las dos el widget
 * mostraría "—" siempre.
 *
 * Por qué una sola consulta: resolver cada zona en su propia llamada exigía un
 * índice compartido que las respuestas asíncronas pisaban entre sí. Un único
 * comando devuelve todas las horas en orden, y si una zona no existe en el
 * equipo esa línea llega vacía y se muestra "—".
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.mediumWide]
    readonly property string defaultSize: Tokens.mediumWide
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    property var zones: root.parseZones(Plasmoid.configuration.zones)
    property var hours: []

    function defaultZones() {
        return [
            { "label": "Madrid", "zone": "Europe/Madrid" },
            { "label": "UTC", "zone": "UTC" },
            { "label": "Nueva York", "zone": "America/New_York" }
        ];
    }

    function parseZones(raw) {
        try {
            const value = JSON.parse(raw || "[]");
            return Array.isArray(value) && value.length > 0 ? value : defaultZones();
        } catch (error) {
            return defaultZones();
        }
    }

    /* Comando único: una línea por zona, en el mismo orden que `zones`.
     *
     * TZ va como prefijo de entorno del comando, NO dentro de -d: la forma
     * `date -d 'TZ=X now'` es inválida (verificado, GNU date la rechaza).
     *
     * La zona se valida contra /usr/share/zoneinfo antes de usarla: con una
     * zona inexistente, `date` NO falla, cae a UTC en silencio y el widget
     * mostraba 21:36 como si fuera local. Una zona desconocida deja la línea
     * vacía y el widget muestra "—".
     */
    function buildCommand() {
        const parts = [];
        for (let i = 0; i < root.zones.length; ++i) {
            const zone = String(root.zones[i].zone || "").replace(/[^A-Za-z0-9_+\/-]/g, "");
            parts.push("if [ -f \"/usr/share/zoneinfo/" + zone + "\" ]; then "
                       + "printf '%s\\n' \"$(TZ=" + zone + " date +%H:%M 2>/dev/null)\"; "
                       + "else printf '\\n'; fi");
        }
        return parts.join("; ");
    }

    Timer {
        id: poll
        interval: 30000
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
            const lines = String(data.stdout || "").split("\n");
            const list = [];
            for (let i = 0; i < root.zones.length; ++i)
                list.push((lines[i] || "").trim());
            root.hours = list;
        }
    }

    function refresh() {
        if (root.zones.length === 0)
            return;
        reader.connectSource(root.buildCommand());
    }

    function hourFor(index) {
        return index >= 0 && index < root.hours.length ? root.hours[index] : "";
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(Tokens.mediumWide, root.cellSize)
        implicitHeight: root.cellSize

        WidgetShell {
            anchors.fill: parent
            title: "Reloj mundial"

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Tokens.space1

                Repeater {
                    // Cuántas zonas caben según el alto real disponible.
                    model: root.zones.slice(0, Math.max(2, Math.floor(
                               (root.cellSize - Tokens.space6) / Tokens.space5)))

                    delegate: Item {
                        id: zoneRow
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: Tokens.space5

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: zoneRow.modelData.label
                            color: Tokens.lightGray
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSizeCaption
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.hourFor(zoneRow.index) || "—"
                            color: Tokens.white
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSizeBody
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }
}
