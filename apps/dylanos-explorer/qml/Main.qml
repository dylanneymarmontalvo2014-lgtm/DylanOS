import QtQuick
import QtQuick.Controls.Basic
import DylanOS.Explorer

ApplicationWindow {
    id: win
    width: 1384
    height: 805
    minimumWidth: 940
    minimumHeight: 580
    visible: true
    title: explorer.title + " — DylanOS Explorer"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    readonly property bool maximized: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property int cornerRadius: maximized ? 0 : Theme.radiusWindow
    readonly property bool textFocus: activeFocusItem !== null && activeFocusItem.hasOwnProperty("cursorPosition")
    readonly property bool modalOpen: confirm.opened || prompt.opened || props.opened || settings.opened
    readonly property bool keysOn: !textFocus && !modalOpen
    readonly property int selCount: explorer.model.selectedCount

    ExplorerController { id: explorer }
    PlacesService { id: placesService }

    Connections {
        target: explorer
        function onNotify(kind, message) { toast.show(kind, message) }
    }

    // ------------------------------------------------------------ frame
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: win.cornerRadius
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.surfaceTop }
            GradientStop { position: 1; color: Theme.surfaceBottom }
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.55; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0.62, 0.05, 0.09, 0.2) }
            }
        }

        Sidebar {
            id: sidebar
            width: Theme.sidebarWidth
            height: parent.height
            cornerRadius: win.cornerRadius
            ctl: explorer
            places: placesService
            window: win
            onSettingsRequested: settings.open()
            onItemContext: (path, x, y) => win.openMenu("place", { path: path }, x, y)
        }

        Item {
            id: main
            anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }

            Header {
                id: header
                width: parent.width
                ctl: explorer
                window: win
            }
            HomePage {
                anchors { top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
                visible: explorer.isHome
                ctl: explorer
                places: placesService
                onFolderMenu: (f, x, y) => win.openMenu("folder", f, x, y)
                onRecentMenu: (f, x, y) => win.openMenu("recent", f, x, y)
            }
            DirectoryPage {
                anchors { top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
                visible: !explorer.isHome
                ctl: explorer
                onItemContext: (r, x, y) => win.openMenu("item", {}, x, y)
                onBackgroundContext: (x, y) => win.openMenu("background", {}, x, y)
                onSortMenu: (x, y) => win.openMenu("sort", {}, x, y)
                onEmptyTrashRequested: win.askEmptyTrash()
            }
        }

        Toast {
            id: toast
            anchors { horizontalCenter: main.horizontalCenter; bottom: parent.bottom; bottomMargin: 54 }
            z: 50
        }
        ProgressPanel {
            ctl: explorer
            visible: explorer.busy
            anchors { right: parent.right; bottom: parent.bottom; margins: 22 }
            z: 51
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.border
            z: 100
        }
    }

    // ------------------------------------------------------------ resize edges
    ResizeEdge { window: win; visible: !win.maximized; edges: Qt.TopEdge; cursor: Qt.SizeVerCursor; height: 5; anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 } }
    ResizeEdge { window: win; visible: !win.maximized; edges: Qt.BottomEdge; cursor: Qt.SizeVerCursor; height: 5; anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 } }
    ResizeEdge { window: win; visible: !win.maximized; edges: Qt.LeftEdge; cursor: Qt.SizeHorCursor; width: 5; anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 12; bottomMargin: 12 } }
    ResizeEdge { window: win; visible: !win.maximized; edges: Qt.RightEdge; cursor: Qt.SizeHorCursor; width: 5; anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 12; bottomMargin: 12 } }
    ResizeEdge { window: win; visible: !win.maximized; edges: Qt.TopEdge | Qt.LeftEdge; cursor: Qt.SizeFDiagCursor; width: 12; height: 12; anchors { top: parent.top; left: parent.left } }
    ResizeEdge { window: win; visible: !win.maximized; edges: Qt.TopEdge | Qt.RightEdge; cursor: Qt.SizeBDiagCursor; width: 12; height: 12; anchors { top: parent.top; right: parent.right } }
    ResizeEdge { window: win; visible: !win.maximized; edges: Qt.BottomEdge | Qt.LeftEdge; cursor: Qt.SizeBDiagCursor; width: 12; height: 12; anchors { bottom: parent.bottom; left: parent.left } }
    ResizeEdge { window: win; visible: !win.maximized; edges: Qt.BottomEdge | Qt.RightEdge; cursor: Qt.SizeFDiagCursor; width: 12; height: 12; anchors { bottom: parent.bottom; right: parent.right } }

    // ------------------------------------------------------------ context menu
    property string menuKind
    property var menuData: ({})

    ContextMenu {
        id: menu
        onTriggered: (id) => win.runAction(id)
    }

    function selectedPath() {
        const p = explorer.model.selectedPaths()
        return p.length === 1 ? p[0] : ""
    }
    function baseName(p) { return p.split("/").filter(s => s !== "").pop() || p }

    function openMenu(kind, data, x, y) {
        menuKind = kind
        menuData = data
        let items = []
        const n = selCount
        const single = n === 1
        if (kind === "item") {
            if (explorer.inTrash) {
                items = [
                    { id: "restore", text: "Restaurar", icon: "restore" },
                    { separator: true },
                    { id: "props", text: "Propiedades", icon: "info", enabled: single },
                    { separator: true },
                    { id: "delete", text: "Eliminar definitivamente", icon: "trash", danger: true }
                ]
            } else {
                items = [
                    { id: "open", text: "Abrir", icon: "open", enabled: single },
                    { separator: true },
                    { id: "copy", text: "Copiar", icon: "copy" },
                    { id: "cut", text: "Cortar", icon: "cut" },
                    { id: "paste", text: "Pegar aquí", icon: "paste", enabled: explorer.canPaste },
                    { separator: true },
                    { id: "rename", text: "Renombrar", icon: "rename", enabled: single },
                    { id: "props", text: "Propiedades", icon: "info" },
                    { separator: true },
                    { id: "trash", text: "Mover a la papelera", icon: "trash", danger: true },
                    { id: "delete", text: "Eliminar definitivamente", icon: "close", danger: true }
                ]
            }
        } else if (kind === "background") {
            items = explorer.inTrash
                ? [ { id: "emptyTrash", text: "Vaciar papelera", icon: "trash", danger: true, enabled: explorer.model.count > 0 },
                    { separator: true },
                    { id: "selectAll", text: "Seleccionar todo", icon: "check" },
                    { id: "refresh", text: "Actualizar", icon: "refresh" } ]
                : [ { id: "newFolder", text: "Nueva carpeta", icon: "folderPlus" },
                    { id: "paste", text: "Pegar", icon: "paste", enabled: explorer.canPaste },
                    { separator: true },
                    { id: "selectAll", text: "Seleccionar todo", icon: "check" },
                    { id: "sortMenu", text: "Ordenar por…", icon: "sort" },
                    { id: "hidden", text: "Mostrar archivos ocultos", icon: "eye", checked: explorer.showHidden },
                    { separator: true },
                    { id: "refresh", text: "Actualizar", icon: "refresh" },
                    { id: "props", text: "Propiedades de la carpeta", icon: "info" } ]
        } else if (kind === "folder") {
            items = [ { id: "openPath", text: "Abrir", icon: "open" }, { id: "propsPath", text: "Propiedades", icon: "info" } ]
        } else if (kind === "recent") {
            items = [ { id: "openFile", text: "Abrir", icon: "open" },
                      { id: "showIn", text: "Mostrar en la carpeta", icon: "folder" },
                      { separator: true },
                      { id: "propsPath", text: "Propiedades", icon: "info" } ]
        } else if (kind === "place") {
            const isTrash = placesService.favorites.some(f => f.path === data.path && f.icon === "trash")
            items = [ { id: "openPlace", text: "Abrir", icon: "open" } ]
            if (isTrash) items.push({ separator: true }, { id: "emptyTrash", text: "Vaciar papelera", icon: "trash", danger: true })
        } else if (kind === "sort") {
            const k = explorer.model.sortKey
            items = [
                { id: "sort0", text: "Nombre", checked: k === 0 }, { id: "sort1", text: "Tamaño", checked: k === 1 },
                { id: "sort2", text: "Fecha de modificación", checked: k === 2 }, { id: "sort3", text: "Tipo", checked: k === 3 },
                { separator: true },
                { id: "asc", text: "Ascendente", checked: explorer.model.sortAscending },
                { id: "desc", text: "Descendente", checked: !explorer.model.sortAscending }
            ]
        }
        menu.openAt(items, x, y)
    }

    function runAction(id) {
        switch (id) {
        case "open": explorer.openSelection(); break
        case "copy": explorer.copySelection(); break
        case "cut": explorer.cutSelection(); break
        case "paste": explorer.paste(); break
        case "rename": askRename(); break
        case "newFolder": askNewFolder(); break
        case "props": showProps(); break
        case "trash": askTrash(); break
        case "delete": askDelete(); break
        case "restore": explorer.restoreSelection(); break
        case "emptyTrash": askEmptyTrash(); break
        case "selectAll": explorer.model.selectAll(); break
        case "refresh": explorer.refresh(); break
        case "hidden": explorer.showHidden = !explorer.showHidden; break
        case "sortMenu": Qt.callLater(() => openMenu("sort", {}, win.width - 260, 130)); break
        case "openPath": explorer.navigate(menuData.path); break
        case "openFile": explorer.openItem(menuData.path); break
        case "showIn": explorer.showInFolder(menuData.path); break
        case "propsPath": props.showFor(menuData.path); break
        case "openPlace": explorer.navigate(menuData.path); break
        case "asc": explorer.model.sortAscending = true; break
        case "desc": explorer.model.sortAscending = false; break
        default:
            if (id.indexOf("sort") === 0) explorer.model.sortKey = parseInt(id.substring(4))
        }
    }

    // ------------------------------------------------------------ dialogs
    property string pendingAction

    function askRename() {
        const p = selectedPath()
        if (p === "") return
        prompt.mode = "rename"; prompt.target = p
        prompt.openWith("Renombrar", "rename", baseName(p), "Renombrar")
    }
    function askNewFolder() {
        if (explorer.isHome || explorer.inTrash) return
        prompt.mode = "newFolder"; prompt.target = ""
        prompt.openWith("Nueva carpeta", "folderPlus", "Nueva carpeta", "Crear")
    }
    function askTrash() {
        if (selCount === 0) return
        if (explorer.inTrash) { askDelete(); return }
        if (!explorer.confirmTrash) { explorer.trashSelection(); return }
        pendingAction = "trash"
        confirm.title = "Mover a la papelera"
        confirm.message = selCount === 1 ? "«" + baseName(selectedPath()) + "» se moverá a la papelera. Podrás restaurarlo después."
                                         : selCount + " elementos se moverán a la papelera. Podrás restaurarlos después."
        confirm.confirmText = "Mover a la papelera"
        confirm.danger = false
        confirm.open()
    }
    function askDelete() {
        if (selCount === 0) return
        pendingAction = "delete"
        confirm.title = "Eliminar definitivamente"
        confirm.message = (selCount === 1 ? "«" + baseName(selectedPath()) + "» se eliminará" : selCount + " elementos se eliminarán")
                          + " de forma permanente. Esta acción no se puede deshacer."
        confirm.confirmText = "Eliminar"
        confirm.danger = true
        confirm.open()
    }
    function askEmptyTrash() {
        pendingAction = "emptyTrash"
        confirm.title = "Vaciar papelera"
        confirm.message = "Todos los elementos de la papelera se eliminarán de forma permanente. Esta acción no se puede deshacer."
        confirm.confirmText = "Vaciar papelera"
        confirm.danger = true
        confirm.open()
    }
    function showProps() {
        const p = selectedPath()
        if (p !== "") props.showFor(p)
        else if (!explorer.isHome) props.showFor(explorer.location)
    }

    ConfirmDialog {
        id: confirm
        onAccepted: {
            if (win.pendingAction === "trash") explorer.trashSelection()
            else if (win.pendingAction === "delete") explorer.deleteSelection()
            else if (win.pendingAction === "emptyTrash") explorer.emptyTrash()
        }
    }
    PromptDialog {
        id: prompt
        property string mode
        property string target
        onSubmitted: (text) => {
            if (mode === "rename") explorer.renameItem(target, text)
            else explorer.createFolder(text)
        }
    }
    PropertiesDialog { id: props; ctl: explorer }
    SettingsDialog { id: settings; ctl: explorer }

    // ------------------------------------------------------------ shortcuts
    Shortcut { sequence: "Alt+Left"; enabled: !win.modalOpen; onActivated: explorer.goBack() }
    Shortcut { sequence: "Alt+Right"; enabled: !win.modalOpen; onActivated: explorer.goForward() }
    Shortcut { sequence: "Alt+Up"; enabled: !win.modalOpen; onActivated: explorer.goUp() }
    Shortcut { sequence: "Alt+Home"; enabled: !win.modalOpen; onActivated: explorer.goHome() }
    Shortcut { sequence: "Backspace"; enabled: win.keysOn; onActivated: explorer.goBack() }
    Shortcut { sequence: "F5"; enabled: !win.modalOpen; onActivated: explorer.refresh() }
    Shortcut { sequence: "Ctrl+F"; enabled: !win.modalOpen; onActivated: header.search.focusField() }
    Shortcut { sequence: "Ctrl+,"; enabled: !win.modalOpen; onActivated: settings.open() }
    Shortcut { sequence: "Ctrl+H"; enabled: !win.modalOpen; onActivated: explorer.showHidden = !explorer.showHidden }
    Shortcut { sequence: "Ctrl+Shift+N"; enabled: win.keysOn; onActivated: win.askNewFolder() }
    Shortcut { sequence: "Ctrl+A"; enabled: win.keysOn && !explorer.isHome; onActivated: explorer.model.selectAll() }
    Shortcut { sequence: "Ctrl+C"; enabled: win.keysOn && win.selCount > 0; onActivated: explorer.copySelection() }
    Shortcut { sequence: "Ctrl+X"; enabled: win.keysOn && win.selCount > 0 && !explorer.inTrash; onActivated: explorer.cutSelection() }
    Shortcut { sequence: "Ctrl+V"; enabled: win.keysOn && !explorer.isHome && explorer.canPaste; onActivated: explorer.paste() }
    Shortcut { sequence: "F2"; enabled: win.keysOn; onActivated: win.askRename() }
    Shortcut { sequence: "Alt+Return"; enabled: win.keysOn; onActivated: win.showProps() }
    Shortcut { sequence: "Delete"; enabled: win.keysOn; onActivated: win.askTrash() }
    Shortcut { sequence: "Shift+Delete"; enabled: win.keysOn; onActivated: win.askDelete() }
    Shortcut { sequence: "Return"; enabled: win.keysOn && win.selCount > 0; onActivated: explorer.openSelection() }
    Shortcut { sequence: "Escape"; enabled: win.keysOn; onActivated: explorer.model.clearSelection() }
}
