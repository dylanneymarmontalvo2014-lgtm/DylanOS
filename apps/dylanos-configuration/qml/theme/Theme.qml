pragma Singleton
import QtQuick

// Tokens de diseño del prototipo DylanOS Configuration (previews/DylanOS configuration).
QtObject {
    id: theme

    property bool dark: true

    // --accent / --accent-strong
    readonly property color accent: "#e0182d"
    readonly property color accentStrong: "#ff2a40"

    // Radios
    readonly property int radiusWindow: 26
    readonly property int radiusCard: 14
    readonly property int radiusTile: 11
    readonly property int radiusControl: 10
    readonly property int sidebarWidth: 338

    // Qt parsea los colores de 8 dígitos como #AARRGGBB (no como #RRGGBBAA
    // de CSS): el prototipo web usaba 221618f0, aquí se reordena a f0221618.
    // Sin esto el fondo quedaba casi transparente y la ventana se veía negra.
    readonly property var c: dark ? ({
        winBgTop: "#f0221618",
        winBgMid: "#f5100c0d",
        winBgBottom: "#f0280a0e",
        sidebar: Qt.rgba(0, 0, 0, 0.22),
        surface: Qt.rgba(1, 1, 1, 0.035),
        surfaceHover: Qt.rgba(1, 1, 1, 0.07),
        surfaceStrong: Qt.rgba(1, 1, 1, 0.09),
        border: Qt.rgba(1, 1, 1, 0.075),
        text: "#f4f1f1",
        textDim: "#a9a3a4",
        track: Qt.rgba(1, 1, 1, 0.14),
        field: Qt.rgba(1, 1, 1, 0.05),
        menuBg: Qt.rgba(0.039, 0.031, 0.031, 0.97)
    }) : ({
        winBgTop: "#f7faf6f6",
        winBgMid: "#f7f0e8e9",
        winBgBottom: "#f7e8e0e1",
        sidebar: Qt.rgba(1, 1, 1, 0.55),
        surface: Qt.rgba(0, 0, 0, 0.035),
        surfaceHover: Qt.rgba(0, 0, 0, 0.07),
        surfaceStrong: Qt.rgba(0, 0, 0, 0.1),
        border: Qt.rgba(0, 0, 0, 0.09),
        text: "#1c1516",
        textDim: "#6b6264",
        track: Qt.rgba(0, 0, 0, 0.18),
        field: Qt.rgba(0, 0, 0, 0.045),
        menuBg: Qt.rgba(1, 1, 1, 0.98)
    })

    property color _alphaScratch: "transparent"
    function alpha(colorSpec, factor) {
        // Mezcla un color con transparencia, como color-mix del prototipo.
        // Acepta strings ("#DC143C") o colores: la asignación a `property
        // color` hace la conversión y así .r/.g/.b siempre existen.
        _alphaScratch = colorSpec
        return Qt.rgba(_alphaScratch.r, _alphaScratch.g, _alphaScratch.b, factor)
    }
}
