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
    SystemPalette { id: systemPalette; colorGroup: SystemPalette.Active }
    readonly property bool dark: systemPalette.window.hsvValue < 0.5
    // Superficies
    readonly property color windowColor: dark ? "#111114" : "#f4f3f3"
    readonly property color surfaceColor: dark ? "#15151a" : "#ffffff"
    readonly property color surfaceElevated: dark ? "#1b1b21" : "#f9f8f8"
    readonly property color surfaceSunken: dark ? "#0d0d10" : "#eeecec"
    readonly property color wallpaper: dark ? "#06060a" : "#f8f6f6"

    // Bordes
    readonly property color border: dark ? "#14ffffff" : "#1c1718"
    readonly property color borderStrong: dark ? "#29ffffff" : "#302425"
    readonly property color borderSubtle: dark ? "#0bffffff" : "#141718"
    readonly property color borderHover: dark ? "#12ffffff" : "#211819"

    // Texto
    readonly property color textPrimary: dark ? "#f3f3f5" : "#201a1b"
    readonly property color textSecondary: dark ? "#9c9ca5" : "#62595b"
    readonly property color textTertiary: dark ? "#6b6b74" : "#83787a"

    // Crimson: acento del prototipo (#e0293b) sobre la identidad DylanOS.
    readonly property color red: "#e0293b"
    readonly property color redHover: "#f03c4e"
    readonly property color redPressed: "#b81f30"
    readonly property color redSubtle: dark ? "#24e0293b" : "#18e0293b"
    readonly property color redSubtleBorder: dark ? "#59e0293b" : "#55e0293b"
    readonly property color redSoftText: dark ? "#ff6b78" : "#a50f2e"

    // Semánticos
    readonly property color success: "#32d74b"
    readonly property color warning: "#ff9f0a"
    readonly property color errorColor: "#ff453a"
    readonly property color info: "#0a84ff"
    readonly property color successSubtle: dark ? "#1f32d74b" : "#1832a75b"
    readonly property color warningSubtle: dark ? "#24ff9f0a" : "#18a26800"
    readonly property color infoSubtle: dark ? "#240a84ff" : "#180a64c7"
    readonly property color neutralSubtle: dark ? "#14ffffff" : "#10000000"
    readonly property color trackColor: dark ? "#12ffffff" : "#1c1718"
    readonly property color diskStroke: dark ? "#c7c7cf" : "#686166"

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
