import QtQuick
import org.dylanos.configuration

// Insignia pequeña del prototipo (Estable, Protegido, Sin cable…).
Rectangle {
    id: root
    property string text: ""
    property color tone: Theme.accentStrong

    width: label.implicitWidth + 12
    height: 20
    radius: 4
    color: Qt.rgba(tone.r, tone.g, tone.b, 0.14)
    border.width: 1
    border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.45)
    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 11
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.5
        color: root.tone
    }
}
