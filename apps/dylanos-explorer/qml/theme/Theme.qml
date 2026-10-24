pragma Singleton
import QtQuick

// Visual tokens measured from the DylanOS Crimson reference screenshot.
QtObject {
    // surfaces
    readonly property color bgDeep: "#0a0506"
    readonly property color surfaceTop: "#1d1012"
    readonly property color surfaceBottom: "#100809"
    readonly property color sidebar: "#150b0d"
    readonly property color popup: "#1c1113"
    readonly property color card: Qt.rgba(1, 1, 1, 0.035)
    readonly property color cardHover: Qt.rgba(1, 1, 1, 0.065)
    readonly property color field: Qt.rgba(1, 1, 1, 0.045)
    readonly property color tableHeader: Qt.rgba(1, 1, 1, 0.04)

    // lines
    readonly property color border: Qt.rgba(1, 1, 1, 0.13)
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.07)

    // text
    readonly property color text: "#f4efef"
    readonly property color textDim: "#b9acae"
    readonly property color textFaint: "#857a7c"

    // brand
    readonly property color accent: "#DC143C"
    readonly property color accentBright: "#FF4565"
    readonly property color accentLabel: "#FF7188"
    readonly property color accentDeep: "#A50F2E"
    readonly property color accentDark: "#690A1E"
    readonly property color selection: Qt.rgba(0.86, 0.08, 0.24, 0.22)
    readonly property color selectionBorder: Qt.rgba(0.95, 0.20, 0.35, 0.55)

    // status
    readonly property color danger: "#ff5a64"
    readonly property color success: "#3ecf6e"
    readonly property color warning: "#f2b84b"
    readonly property color info: "#6aa7ff"

    // metrics
    readonly property int radiusWindow: 22
    readonly property int radiusCard: 16
    readonly property int radiusControl: 10
    readonly property int radiusSmall: 8
    readonly property int sidebarWidth: 290
    readonly property int headerHeight: 76
    readonly property int pagePadding: 25
    readonly property int controlHeight: 38

    // type
    readonly property int fontBase: 14
    readonly property int fontSmall: 12
    readonly property int fontItem: 15
    readonly property int fontSection: 17
    readonly property int fontTitle: 22
}
