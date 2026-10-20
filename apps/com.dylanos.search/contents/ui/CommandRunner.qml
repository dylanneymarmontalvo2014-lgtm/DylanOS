import QtQuick
import org.kde.plasma.plasma5support as P5Support

/*
 * Ejecutor de comandos de los plasmoids de DylanOS.
 * El motor "executable" de Plasma5Support corre procesos reales de la sesión.
 */
QtObject {
    function run(command) {
        exec.connectSource(command)
    }

    readonly property P5Support.DataSource exec: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
    }
}