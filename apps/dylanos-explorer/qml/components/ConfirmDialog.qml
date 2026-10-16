import QtQuick
import DylanOS.Explorer

DlgBase {
    id: root
    property string message
    property string confirmText: "Aceptar"
    property bool danger: false
    signal accepted()

    icon: danger ? "warning" : "info"
    tint: danger ? Theme.danger : Theme.accentLabel

    Txt {
        width: parent.width
        text: root.message
        color: Theme.textDim
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }
    footer: [
        DButton { text: "Cancelar"; onClicked: root.close() },
        DButton {
            text: root.confirmText
            variant: root.danger ? "danger" : "primary"
            onClicked: { root.close(); root.accepted() }
        }
    ]
}
