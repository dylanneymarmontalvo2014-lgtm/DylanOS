pragma Singleton
import QtQuick

QtObject {
    id: root
    readonly property FontLoader onest: FontLoader { source: "qrc:/data/fonts/Onest.ttf" }
    readonly property string family: onest.status === FontLoader.Ready ? onest.name : "Sans Serif"
    readonly property int xs: 12
    readonly property int tiny: 11
    readonly property int sm: 14
    readonly property int body: 15
    readonly property int lg: 18
    readonly property int h1: 24
    readonly property int display: 30
    readonly property int hero: 36
    readonly property int weightMedium: Font.Medium
    readonly property int weightSemibold: Font.DemiBold
}
