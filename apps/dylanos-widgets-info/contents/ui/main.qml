pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens
import "lib/WidgetData.js" as Data

/*
 * DylanOS Widgets — DylanOS Info.
 *
 * Resumen del sistema con las mismas fuentes que DylanOS Configuration:
 * os-release, /proc/cpuinfo (con la cadena de respaldo a lscpu cuando el
 * kernel omite "model name", p. ej. en QEMU TCG) y /proc/meminfo.
 *
 * No hay un binario `dylanos-info` en el proyecto; la fuente real es
 * SystemService::sysInfo(), y este widget replica sus reglas.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small, Tokens.large]
    readonly property string defaultSize: Tokens.large
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell
    readonly property bool wide: width > height * 1.4

    preferredRepresentation: fullRepresentation

    property string osName: "DylanOS"
    property string osVersion: ""
    property string cpu: ""
    property int memGb: 0
    property string kernel: ""

    // Los datos del sistema no cambian durante la sesión: una sola lectura.
    Timer {
        id: once
        interval: 1
        running: true
        onTriggered: root.refresh()
    }

    P5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const out = data.stdout || "";
            if (sourceName === "cat /usr/lib/os-release") {
                root.parseOsRelease(out);
            } else if (sourceName === "cat /proc/cpuinfo") {
                root.parseCpu(out);
            } else if (sourceName === "cat /proc/meminfo") {
                const mem = Data.parseMemInfo(out);
                if (mem)
                    root.memGb = Data.roundMemoryGb(mem.totalKb);
            } else if (sourceName === "uname -r") {
                root.kernel = out.trim();
            }
        }
    }

    function refresh() {
        reader.connectSource("cat /usr/lib/os-release");
        reader.connectSource("cat /proc/cpuinfo");
        reader.connectSource("cat /proc/meminfo");
        reader.connectSource("uname -r");
    }

    function parseOsRelease(text) {
        const lines = String(text).split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i];
            if (line.indexOf("PRETTY_NAME=") === 0)
                root.osName = line.substr(12).replace(/"/g, "");
            else if (line.indexOf("VERSION=") === 0)
                root.osVersion = line.substr(8).replace(/"/g, "");
        }
    }

    function parseCpu(text) {
        const lines = String(text).split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i];
            // "model name" en x86 y "Hardware" en ARM de 32 bits.
            if (line.indexOf("model name") === 0 || line.indexOf("Hardware") === 0) {
                const value = line.substr(line.indexOf(":") + 1).trim();
                if (value.length > 0) {
                    root.cpu = value;
                    return;
                }
            }
        }
        // Sin marca en CPUID (QEMU TCG con -cpu max) el kernel omite la línea:
        // Configuration cae a lscpu y, si tampoco hay, a "Procesador de N núcleos".
        root.cpu = "";
        reader.connectSource("lscpu");
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(root.wide ? Tokens.large : Tokens.small,
                                       root.cellSize)
        implicitHeight: root.cellSize

        WidgetShell {
            anchors.fill: parent
            title: root.osName
            subtitle: root.kernel.length > 0 ? "Kernel " + root.kernel : ""

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Tokens.space1

                Text {
                    width: parent.width
                    text: root.cpu.length > 0 ? root.cpu : "Procesador no identificado"
                    color: Tokens.white
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeBody
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.memGb > 0 ? root.memGb + " GB de RAM"
                                         : "Memoria no disponible"
                    color: Tokens.lightGray
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeCaption
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.osVersion.length > 0 ? root.osVersion : ""
                    color: Tokens.crimson
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeCaption
                    elide: Text.ElideRight
                }
            }
        }
    }
}
