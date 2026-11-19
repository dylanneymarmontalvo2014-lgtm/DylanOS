// Tokens visuales de DylanOS Process, tomados literalmente del prototipo.
//
// Singleton QML (qmldir + pragma Singleton): cualquier cambio aquí afecta a
// todas las páginas a la vez, y los tests verifican que ningún componente
// declara colores fuera de esta paleta.
//
// IMPORTANTE: Qt interpreta los colores de 8 dígitos como #AARRGGBB (alfa
// primero), NO como el #RRGGBBAA de CSS. Cada translúcido de abajo lleva el
// alfa delante y el valor indicado al lado para que no se invierta por error.

pragma Singleton
import QtQuick

QtObject {
    // Superficies
    readonly property color windowColor: "#111114"
    readonly property color surfaceColor: "#15151a"
    readonly property color surfaceElevated: "#1b1b21"
    readonly property color surfaceSunken: "#0d0d10"
    readonly property color wallpaper: "#06060a"

    // Bordes
    readonly property color border: "#14ffffff"          // blanco al 8 %
    readonly property color borderStrong: "#29ffffff"    // blanco al 16 %
    readonly property color borderSubtle: "#0bffffff"    // blanco al 4,5 %
    readonly property color borderHover: "#12ffffff"     // blanco al 7 %

    // Texto
    readonly property color textPrimary: "#f3f3f5"
    readonly property color textSecondary: "#9c9ca5"
    readonly property color textTertiary: "#6b6b74"

    // Crimson: acento del prototipo (#e0293b) sobre la identidad DylanOS.
    readonly property color red: "#e0293b"
    readonly property color redHover: "#f03c4e"
    readonly property color redPressed: "#b81f30"
    readonly property color redSubtle: "#24e0293b"        // crimson al 14 %
    readonly property color redSubtleBorder: "#59e0293b"  // crimson al 35 %
    readonly property color redSoftText: "#ff6b78"

    // Semánticos
    readonly property color success: "#32d74b"
    readonly property color warning: "#ff9f0a"
    readonly property color errorColor: "#ff453a"
    readonly property color info: "#0a84ff"
    readonly property color successSubtle: "#1f32d74b"    // verde al 12 %
    readonly property color warningSubtle: "#24ff9f0a"    // ámbar al 14 %
    readonly property color infoSubtle: "#240a84ff"       // azul al 14 %
    readonly property color neutralSubtle: "#14ffffff"    // blanco al 8 %
    readonly property color trackColor: "#12ffffff"       // blanco al 7 %
    readonly property color diskStroke: "#c7c7cf"

    // Medidas del prototipo
    readonly property int windowRadius: 18
    readonly property int cardRadius: 13
    readonly property int panelRadius: 14
    readonly property int controlRadius: 9
    readonly property int smallRadius: 7
    readonly property int titleBarHeight: 52
    readonly property int footerHeight: 30
    readonly property int detailWidth: 296
    readonly property int navPadding: 16

    // Tipografía
    readonly property string uiFont: "Inter"
    readonly property string monoFont: "JetBrains Mono"

    // Color del punto de estado del proceso, como en el prototipo.
    function stateColor(state) {
        switch (state) {
        case "Ejecutando": return success
        case "Suspendido": return warning
        case "Espera de E/S": return warning
        case "No responde": return errorColor
        case "Zombi": return errorColor
        case "Detenido": return errorColor
        case "Inactivo": return info
        default: return textTertiary
        }
    }
}
