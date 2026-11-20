pragma Singleton
import QtQuick

// Single source of truth for colour. Values mirror the React prototype (src/index.css).
QtObject {
    SystemPalette { id: systemPalette; colorGroup: SystemPalette.Active }
    readonly property bool dark: systemPalette.window.hsvValue < 0.5
    readonly property color bg: dark ? "#070405" : "#f4f2f2"
    readonly property color panel: dark ? "#0f0a0b" : "#ffffff"
    readonly property color surface: dark ? "#170f11" : "#ffffff"
    readonly property color surface2: dark ? "#1f1416" : "#f5f2f2"
    readonly property color surfaceHover: dark ? "#2b1c1f" : "#eee9e9"
    readonly property color line: dark ? "#2a1a1d" : "#d9d0d1"
    readonly property color fg: dark ? "#f4eeee" : "#211a1b"
    readonly property color dim: dark ? "#b3a6a8" : "#655b5d"
    readonly property color faint: dark ? "#8a7b7e" : "#817679"
    readonly property color crimson: dark ? "#c0181f" : "#a50f2e"
    readonly property color crimsonHi: dark ? "#e02a31" : "#a50f2e"
    readonly property color ok: "#3ecf8e"
    readonly property color warn: "#f2b84b"
    readonly property color red300: dark ? "#ff8087" : "#a50f2e"
    readonly property color red400: dark ? "#ff6b72" : "#b20d32"
    readonly property color red500: dark ? "#ff5058" : "#b20d32"
    readonly property color dangerLine: dark ? "#6b1a1f" : "#e1adb2"
    readonly property color dangerBg: dark ? "#2a0d10" : "#fff0f1"
    readonly property color dangerHover: dark ? "#3a0f13" : "#ffe3e5"

    function alpha(c, a) { const k = Qt.color(c); return Qt.rgba(k.r, k.g, k.b, a) }
    function white(a) { return dark ? Qt.rgba(1, 1, 1, a) : Qt.rgba(0, 0, 0, a) }
    readonly property color surface70: alpha(surface, 0.7)
    readonly property color surface60: alpha(surface, 0.6)
    readonly property color surface50: alpha(surface, 0.5)
}
