pragma Singleton
import QtQuick

// Visual tokens measured from the DylanOS Crimson reference screenshot.
QtObject {
    SystemPalette { id: systemPalette; colorGroup: SystemPalette.Active }
    readonly property bool dark: systemPalette.window.hsvValue < 0.5
    // surfaces
    readonly property color bgDeep: dark ? "#0a0506" : "#f4f1f1"
    readonly property color surfaceTop: dark ? "#1d1012" : "#ffffff"
    readonly property color surfaceBottom: dark ? "#100809" : "#f7f5f5"
    readonly property color sidebar: dark ? "#150b0d" : "#eeebeb"
    readonly property color popup: dark ? "#1c1113" : "#ffffff"
    readonly property color card: dark ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(0, 0, 0, 0.035)
    readonly property color cardHover: dark ? Qt.rgba(1, 1, 1, 0.065) : Qt.rgba(0, 0, 0, 0.065)
    readonly property color field: dark ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(0, 0, 0, 0.045)
    readonly property color tableHeader: dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.04)

    // lines
    readonly property color border: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.12)
    readonly property color hairline: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.08)

    // text
    readonly property color text: dark ? "#f4efef" : "#211a1b"
    readonly property color textDim: dark ? "#b9acae" : "#655b5d"
    readonly property color textFaint: dark ? "#857a7c" : "#827779"

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
