import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

RowLayout {
    id: notesPage
    objectName: "notesPage"
    spacing: 18
    property string noteId: ""
    property bool dirty: false
    property bool loading: false
    property string stateText: "Guardado local en este equipo"
    function flush() {
        saveTimer.stop()
        if (!dirty) return true
        let saved = backend.saveNote(noteId, noteTitle.text, body.text)
        if (!saved) { stateText = "No se pudo guardar. Tu texto sigue aquí."; return false }
        noteId = saved; dirty = false; stateText = "Todos los cambios guardados"
        return true
    }
    function edit() { if (!loading) { dirty = true; stateText = "Guardando…"; saveTimer.restart() } }
    function select(note) {
        if (!flush()) return
        loading = true; noteId = note.id; noteTitle.text = note.title; body.text = note.body; loading = false; dirty = false
    }
    Timer { id: saveTimer; interval: 700; onTriggered: notesPage.flush() }
    Shortcut { sequence: "Ctrl+S"; onActivated: notesPage.flush() }
    Surface {
        Layout.preferredWidth: 235; Layout.fillHeight: true; padding: 12
        ColumnLayout {
            anchors.fill: parent; spacing: 12
            ActionButton { text: "+ Nueva nota"; primary: true; Layout.fillWidth: true; onClicked: { notesPage.select({id:"", title:"", body:""}); noteTitle.forceActiveFocus() } }
            Field { id: search; placeholderText: "Buscar notas"; Layout.fillWidth: true }
            ListView {
                id: noteList; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 5
                model: backend.notes.filter(n => (n.title + " " + n.body).toLowerCase().includes(search.text.toLowerCase()))
                ScrollBar.vertical: ScrollBar {}
                delegate: Selectable {
                    required property var modelData
                    width: noteList.width; height: 78; highlighted: notesPage.noteId === modelData.id
                    onClicked: notesPage.select(modelData)
                    contentItem: ColumnLayout {
                        Label { text: modelData.title; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                        Label { text: modelData.body.replace(/\n/g, " ") || "Nota vacía"; elide: Text.ElideRight; font.pixelSize: 11; color: palette.placeholderText; Layout.fillWidth: true }
                    }
                }
                Label { anchors.centerIn: parent; visible: noteList.count === 0; text: "Tus ideas empiezan aquí."; font.pixelSize: 11; color: palette.placeholderText }
            }
            Label { text: backend.notes.length + " notas · solo en este equipo"; font.pixelSize: 10; color: palette.placeholderText }
        }
    }
    Surface {
        Layout.fillWidth: true; Layout.fillHeight: true; padding: 24
        ColumnLayout {
            anchors.fill: parent; spacing: 16
            Field { id: noteTitle; objectName: "noteTitle"; placeholderText: "Una nueva idea"; font.pixelSize: 25; font.weight: Font.DemiBold; Layout.fillWidth: true; selectByMouse: true; onTextEdited: notesPage.edit(); background: Item {} }
            Rectangle { height: 1; Layout.fillWidth: true; color: palette.mid }
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true
                TextArea { id: body; objectName: "noteBody"; placeholderText: "Escribe sin distracciones…"; wrapMode: TextEdit.Wrap; selectByMouse: true; font.pixelSize: 15; textFormat: TextEdit.PlainText; onTextChanged: notesPage.edit(); background: Item {} }
            }
            RowLayout {
                Label { text: notesPage.stateText; font.pixelSize: 10; color: palette.placeholderText; Layout.fillWidth: true }
                ActionButton { text: "Guardar"; enabled: notesPage.dirty; onClicked: notesPage.flush() }
                ActionButton { text: "Eliminar"; enabled: notesPage.noteId !== ""; onClicked: removeDialog.open() }
            }
        }
    }
    Dialog {
        id: removeDialog; modal: true; title: "Eliminar nota"; anchors.centerIn: parent; width: 340
        standardButtons: Dialog.Ok | Dialog.Cancel
        Label { text: "Esta nota se eliminará de este equipo. Esta acción no se puede deshacer."; width: parent.width; wrapMode: Text.Wrap }
        onAccepted: {
            saveTimer.stop()
            if (!backend.deleteNote(notesPage.noteId)) return
            notesPage.dirty = false; notesPage.select({id:"", title:"", body:""})
        }
    }
}
