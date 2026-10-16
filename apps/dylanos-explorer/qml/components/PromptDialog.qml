import QtQuick
import DylanOS.Explorer

DlgBase {
    id: root
    property string initial
    property string confirmText: "Aceptar"
    property string error
    signal submitted(string text)

    function openWith(titleText, icon_, initialText, confirmLabel) {
        title = titleText
        icon = icon_
        initial = initialText
        confirmText = confirmLabel
        error = ""
        input.text = initialText
        open()
    }
    function validate(t) {
        const s = t.trim()
        if (s === "") return "El nombre no puede estar vacío."
        if (s.indexOf("/") >= 0) return "El nombre no puede contener «/»."
        if (s === "." || s === "..") return "Ese nombre no es válido."
        return ""
    }
    function submit() {
        error = validate(input.text)
        if (error === "") { close(); submitted(input.text.trim()) }
    }
    onOpened: {
        input.forceActiveFocus()
        const dot = initial.lastIndexOf(".")
        input.select(0, dot > 0 ? dot : initial.length)
    }

    Rectangle {
        width: parent.width; height: 42; radius: 10
        color: Theme.field
        border.width: 1
        border.color: root.error !== "" ? Theme.danger : (input.activeFocus ? Theme.accentDeep : Theme.hairline)
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            font.pixelSize: Theme.fontBase + 1
            selectionColor: Theme.accentDeep
            clip: true
            onAccepted: root.submit()
            onTextChanged: root.error = ""
        }
    }
    Txt {
        visible: root.error !== ""
        width: parent.width
        text: root.error
        color: Theme.danger
        font.pixelSize: Theme.fontSmall + 1
    }
    footer: [
        DButton { text: "Cancelar"; onClicked: root.close() },
        DButton { text: root.confirmText; variant: "primary"; onClicked: root.submit() }
    ]
}
