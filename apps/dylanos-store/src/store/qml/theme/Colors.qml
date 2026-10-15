pragma Singleton
import QtQuick

// Single source of truth for colour. Values mirror the React prototype (src/index.css).
QtObject {
    readonly property color bg: "#070405"
    readonly property color panel: "#0f0a0b"
    readonly property color surface: "#170f11"
    readonly property color surface2: "#1f1416"
    readonly property color surfaceHover: "#2b1c1f"
    readonly property color line: "#2a1a1d"
    readonly property color fg: "#f4eeee"
    readonly property color dim: "#b3a6a8"
    readonly property color faint: "#8a7b7e"
    readonly property color crimson: "#c0181f"
    readonly property color crimsonHi: "#e02a31"
    readonly property color ok: "#3ecf8e"
    readonly property color warn: "#f2b84b"
    readonly property color red300: "#ff8087"
    readonly property color red400: "#ff6b72"
    readonly property color red500: "#ff5058"
    readonly property color dangerLine: "#6b1a1f"
    readonly property color dangerBg: "#2a0d10"
    readonly property color dangerHover: "#3a0f13"

    function alpha(c, a) { const k = Qt.color(c); return Qt.rgba(k.r, k.g, k.b, a) }
    function white(a) { return Qt.rgba(1, 1, 1, a) }
    readonly property color surface70: alpha(surface, 0.7)
    readonly property color surface60: alpha(surface, 0.6)
    readonly property color surface50: alpha(surface, 0.5)
}
