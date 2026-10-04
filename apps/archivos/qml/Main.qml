import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ApplicationWindow {
    id: win
    visible: true
    width: 1180
    height: 720
    minimumWidth: 900
    minimumHeight: 560
    title: "Archivos"
    color: cBg

    // ---------- Paleta (idéntica al prototipo v2 aprobado) ----------
    readonly property color cBg: "#1c1c1e"
    readonly property color cBgElevated: "#242426"
    readonly property color cBgSidebar: "#1f1f21"
    readonly property color cBgHover: "#2d2d30"
    readonly property color cBorder: "#333335"
    readonly property color cText: "#f2f2f2"
    readonly property color cTextDim: "#a6a6a8"
    readonly property color cTextFaint: "#6e6e70"
    readonly property color cAccent: "#b8433f"
    readonly property color cAccentSoft: "#33191a"

    property string assetsPath: "file://" + appDir + "/assets/"

    // ---------- Árbol de archivos de ejemplo (navegable) ----------
    function emptyFolder(name, icon) { return {name:name, type:"folder", icon:icon, children:[]}; }

    property var imagenesFolder: ({
        name:"Imágenes", type:"folder", icon:"images",
        children:[
            {name:"Fototeca de Photo Booth", type:"folder", icon:"generic", children:[
                {name:"Recorte 2024.png", type:"file", ext:"PNG", size:"420 KB", mod:"3 mar 2024"}
            ]},
            {name:"safari", type:"folder", icon:"generic", children:[]},
            {name:"Atajos pdf", type:"folder", icon:"generic", children:[
                {name:"atajos-teclado.pdf", type:"file", ext:"PDF", size:"88 KB", mod:"10 ene 2025"}
            ]},
            {name:"Monosnap", type:"folder", icon:"generic", children:[]},
            {name:"Fotos biblioteca", type:"folder", icon:"images", children:[
                {name:"vacaciones.heic", type:"file", ext:"HEIC", size:"2,1 MB", mod:"1 jul 2025"}
            ]},
            {name:"documentos", type:"file", ext:"XLSX", size:"1,2 MB", mod:"12 sep 2026"},
            {name:"imágenes", type:"folder", icon:"images", children:[]},
            {name:"documentos", type:"folder", icon:"documents", children:[
                {name:"informe.docx", type:"file", ext:"DOCX", size:"310 KB", mod:"5 ago 2026"},
                {name:"proyectos", type:"folder", icon:"generic", children:[]}
            ]}
        ]
    })
    property var sidebarFolders: ({
        recientes: emptyFolder("Recientes","generic"),
        escritorio: emptyFolder("Escritorio","desktop"),
        documentos: emptyFolder("Documentos","documents"),
        descargas: emptyFolder("Descargas","downloads"),
        imagenes: imagenesFolder,
        musica: emptyFolder("Música","music"),
        videos: emptyFolder("Vídeos","video"),
        aplicaciones: emptyFolder("Aplicaciones","apps")
    })
    property var rootNode: ({name:"Inicio", type:"folder", icon:"generic", children:[imagenesFolder]})

    property var favRows: [
        {key:"recientes", label:"Recientes"},
        {key:"escritorio", label:"Escritorio"},
        {key:"documentos", label:"Documentos"},
        {key:"descargas", label:"Descargas"},
        {key:"imagenes", label:"Imágenes"},
        {key:"musica", label:"Música"},
        {key:"videos", label:"Vídeos"},
        {key:"aplicaciones", label:"Aplicaciones"}
    ]
    property string activeSidebarKey: "imagenes"

    // ---------- Estado de navegación ----------
    property var path: [rootNode, imagenesFolder]
    property var historyStack: [ [rootNode, imagenesFolder] ]
    property int historyIndex: 0
    property bool canGoBack: historyIndex > 0
    property bool canGoForward: historyIndex < historyStack.length - 1

    function currentFolder() { return path[path.length - 1]; }
    function currentItems() { return currentFolder().children; }

    function applyPath(newPath) {
        path = newPath;
        deselectAll();
        refreshItems();
        columnPreviewNode = null;
        rebuildColumnsModel();
        gallerySelected = currentItems().length ? 0 : null;
        canGoBack = historyIndex > 0;
        canGoForward = historyIndex < historyStack.length - 1;
    }
    function navigate(newPath) {
        historyStack = historyStack.slice(0, historyIndex + 1);
        historyStack.push(newPath);
        historyIndex = historyStack.length - 1;
        applyPath(newPath);
    }
    function goBack() { if (historyIndex <= 0) return; historyIndex--; applyPath(historyStack[historyIndex]); }
    function goForward() { if (historyIndex >= historyStack.length - 1) return; historyIndex++; applyPath(historyStack[historyIndex]); }
    function enterFolder(idx) {
        var node = currentItems()[idx];
        if (node.type !== "folder") return;
        if (!node.children) node.children = [];
        var np = path.slice();
        np.push(node);
        navigate(np);
    }
    function goToFolder(key) {
        var node = sidebarFolders[key];
        if (!node) return;
        activeSidebarKey = key;
        navigate([rootNode, node]);
    }
    function navigateToCrumb(i) { navigate(path.slice(0, i + 1)); }

    // ---------- Modelo de la carpeta activa ----------
    ListModel { id: itemsModel }
    property string statusText: "elementos"
    property string searchQuery: ""

    function refreshItems() {
        itemsModel.clear();
        var items = currentItems();
        for (var i = 0; i < items.length; i++) {
            var it = items[i];
            itemsModel.append({
                iIdx: i, iName: it.name, iType: it.type, iIcon: it.icon || "generic",
                iExt: it.ext || "", iSize: it.size || "", iMod: it.mod || ""
            });
        }
        updateStatusForSelection();
    }

    // ---------- Selección ----------
    property var selectedIndices: []
    property int lastSelectedIdx: -1

    function selectItem(idx, modifiers) {
        var additive = (modifiers & Qt.ControlModifier) !== 0;
        var range = (modifiers & Qt.ShiftModifier) !== 0 && lastSelectedIdx !== -1;
        var sel;
        if (range) {
            var a = Math.min(lastSelectedIdx, idx), b = Math.max(lastSelectedIdx, idx);
            sel = [];
            for (var i = a; i <= b; i++) sel.push(i);
        } else if (additive) {
            sel = selectedIndices.slice();
            var pos = sel.indexOf(idx);
            if (pos === -1) sel.push(idx); else sel.splice(pos, 1);
            lastSelectedIdx = idx;
        } else {
            sel = [idx];
            lastSelectedIdx = idx;
        }
        selectedIndices = sel;
        updateStatusForSelection();
    }
    function deselectAll() { selectedIndices = []; lastSelectedIdx = -1; updateStatusForSelection(); }
    function selectAllItems() {
        var arr = [];
        for (var i = 0; i < currentItems().length; i++) arr.push(i);
        selectedIndices = arr;
        updateStatusForSelection();
    }
    function updateStatusForSelection() {
        var n = selectedIndices.length, total = currentItems().length;
        statusText = n > 0 ? (n + " de " + total + " seleccionados, 404,73 GB disponibles")
                            : (total + " elementos, 404,73 GB disponibles");
    }
    function flash(msg) { statusText = msg; flashResetTimer.restart(); }
    Timer { id: flashResetTimer; interval: 2500; onTriggered: win.updateStatusForSelection() }

    // ---------- Favoritos, etiquetas, portapapeles ----------
    property var favorites: []
    function addToFavorites(idx) {
        var it = currentItems()[idx];
        if (it.type !== "folder") { flash("Solo las carpetas pueden ir a Favoritos"); return; }
        for (var i = 0; i < favorites.length; i++) if (favorites[i].name === it.name) { flash('"' + it.name + '" ya está en Favoritos'); return; }
        var f = favorites.slice();
        f.push({name: it.name, icon: it.icon});
        favorites = f;
        flash('"' + it.name + '" agregado a Favoritos');
    }
    function removeFavorite(i) { var f = favorites.slice(); f.splice(i, 1); favorites = f; }

    property var tagColors: [
        {id:"violeta", hex:"#9b6bd6", label:"Violeta"},
        {id:"naranja", hex:"#e2872b", label:"Naranja"},
        {id:"gris", hex:"#8a8a8a", label:"Gris"},
        {id:"amarilla", hex:"#e0c22b", label:"Amarilla"},
        {id:"roja", hex:"#b8433f", label:"Roja"},
        {id:"verde", hex:"#3fae5c", label:"Verde"}
    ]
    property var tagState: ({})
    function assignTag(idx, color) {
        var t = {};
        for (var k in tagState) t[k] = tagState[k];
        t[String(idx)] = color;
        tagState = t;
    }
    function usedTagColors() {
        var used = [], seen = {};
        for (var k in tagState) { var c = tagState[k]; if (!seen[c.id]) { seen[c.id] = true; used.push(c); } }
        return used;
    }
    function tagCount(id) {
        var n = 0;
        for (var k in tagState) if (tagState[k].id === id) n++;
        return n;
    }

    property var clipboardItem: null
    function copyItem(idx) { clipboardItem = {idx: idx, mode:"copy", node: currentItems()[idx]}; flash('"' + currentItems()[idx].name + '" copiado'); }
    function cutItem(idx) { clipboardItem = {idx: idx, mode:"cut", node: currentItems()[idx]}; flash('"' + currentItems()[idx].name + '" listo para mover'); }
    function extColor(ext) {
        var m = { XLSX:"#1f8f52", XLS:"#1f8f52", PDF:"#c0392b", DOCX:"#2b579a", DOC:"#2b579a",
                  PNG:"#2b7fe0", JPG:"#2b7fe0", JPEG:"#2b7fe0", HEIC:"#8e44ad", GIF:"#2b7fe0",
                  MP3:"#8e44ad", MP4:"#e2872b", ZIP:"#6e6e70", TXT:"#6e6e70" };
        return m[ext] || "#5a5a5c";
    }
    function nextCopyName(name) {
        var base = name.replace(/ copia( \d+)?$/, "");
        var items = currentItems(), existing = {};
        for (var i = 0; i < items.length; i++) existing[items[i].name] = true;
        if (!existing[base + " copia"]) return base + " copia";
        var n = 2;
        while (existing[base + " copia " + n]) n++;
        return base + " copia " + n;
    }
    function pasteItem() {
        if (!clipboardItem) return;
        var items = currentItems();
        if (clipboardItem.mode === "copy") {
            var clone = JSON.parse(JSON.stringify(clipboardItem.node));
            clone.name = nextCopyName(clone.name);
            items.push(clone);
            flash("Elemento pegado");
        } else {
            flash('"' + clipboardItem.node.name + '" movido aquí');
            clipboardItem = null;
        }
        refreshItems();
        rebuildColumnsModel();
    }
    function duplicateItem(idx) {
        var items = currentItems();
        var clone = JSON.parse(JSON.stringify(items[idx]));
        clone.name = nextCopyName(items[idx].name);
        items.splice(idx + 1, 0, clone);
        refreshItems();
        rebuildColumnsModel();
        flash('"' + clone.name + '" creado');
    }
    function trashItem(idx) {
        var items = currentItems();
        var name = items[idx].name;
        items.splice(idx, 1);
        deselectAll();
        refreshItems();
        rebuildColumnsModel();
        flash('"' + name + '" movido a la papelera');
    }
    function createNewFolder() {
        var items = currentItems(), existing = {};
        for (var i = 0; i < items.length; i++) existing[items[i].name] = true;
        var name = "nueva carpeta", n = 2;
        while (existing[name]) { name = "nueva carpeta " + n; n++; }
        items.unshift({name:name, type:"folder", icon:"generic", children:[]});
        refreshItems();
        rebuildColumnsModel();
        renameDialog.openFor(0, name);
    }
    function sortItemsBy(by) {
        var items = currentItems();
        items.sort(function(a, b) {
            if (by === "type") { var ra = a.type==="folder"?0:1, rb = b.type==="folder"?0:1; return ra!==rb ? ra-rb : a.name.localeCompare(b.name); }
            if (by === "name") return a.name.localeCompare(b.name);
            if (by === "size") { var sa = a.type==="folder"?-1:(parseFloat(a.size)||0); var sb = b.type==="folder"?-1:(parseFloat(b.size)||0); return sa-sb; }
            if (by === "mod") return (a.mod||"").localeCompare(b.mod||"");
            return 0;
        });
        refreshItems();
        rebuildColumnsModel();
    }

    property string currentView: "grid"

    // ---------- Vista en columnas ----------
    property var columnsModel: []
    property var columnPreviewNode: null
    function rebuildColumnsModel() {
        var m = [];
        for (var k = 0; k < path.length; k++) {
            m.push({ children: path[k].children, activeName: (k + 1 < path.length) ? path[k + 1].name : null });
        }
        columnsModel = m;
    }
    function columnItemClicked(colIdx, itemIdx) {
        var node = columnsModel[colIdx].children[itemIdx];
        if (!node) return;
        if (node.type === "folder") {
            if (!node.children) node.children = [];
            columnPreviewNode = null;
            navigate(path.slice(0, colIdx + 1).concat([node]));
        } else {
            columnPreviewNode = node;
            rebuildColumnsModel();
        }
    }

    // ---------- Vista galería ----------
    property var gallerySelected: null
    function gallerySelNode() {
        var arr = currentItems();
        if (gallerySelected === null || gallerySelected < 0 || gallerySelected >= arr.length) return null;
        return arr[gallerySelected];
    }
    function gallerySelType() { var n = gallerySelNode(); return n ? n.type : ""; }
    function gallerySelName() { var n = gallerySelNode(); return n ? n.name : ""; }
    function gallerySelExt() { var n = gallerySelNode(); return n ? (n.ext || "") : ""; }
    function galleryMeta() {
        var n = gallerySelNode();
        if (!n) return "";
        return n.type === "folder" ? ((n.children ? n.children.length : 0) + " elementos") : ((n.size || "—") + " · " + (n.mod || "—"));
    }
    function galleryIconSource() {
        var n = gallerySelNode();
        if (!n) return "";
        return n.type === "folder" ? (assetsPath + "folder-" + (n.icon || "generic") + ".svg") : (assetsPath + "file-generic.svg");
    }

    // ---------- Selección por arrastre (marquee) ----------
    function marqueeSelect(x1, y1, x2, y2, scrollY, viewWidth) {
        var cols = Math.max(1, Math.floor(viewWidth / 100));
        var sel = [];
        var n = currentItems().length;
        for (var i = 0; i < n; i++) {
            var col = i % cols, row = Math.floor(i / cols);
            var cx1 = col * 100, cy1 = row * 108 - scrollY;
            var cx2 = cx1 + 100, cy2 = cy1 + 108;
            if (!(cx2 < x1 || cx1 > x2 || cy2 < y1 || cy1 > y2)) sel.push(i);
        }
        selectedIndices = sel;
        updateSelectionCount();
    }

    // ---------- Arrastrar carpeta a Favoritos ----------
    function pointInSidebar(gx, gy) {
        var topLeft = sidebarPanel.mapToItem(null, 0, 0);
        return gx >= topLeft.x && gx <= topLeft.x + sidebarPanel.width && gy >= topLeft.y && gy <= topLeft.y + sidebarPanel.height;
    }

    // ---------- Menú contextual genérico (mismo motor que el prototipo HTML) ----------
    Popup {
        id: ctxMenu
        modal: true
        focus: true
        padding: 5
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: "#1c1c1e"; border.color: win.cBorder; radius: 10 }
        property var blocks: []
        contentItem: ColumnLayout {
            spacing: 0
            implicitWidth: 210
            Repeater {
                model: ctxMenu.blocks
                delegate: ColumnLayout {
                    id: blockRow
                    Layout.fillWidth: true
                    spacing: 0
                    property var block: modelData
                    Rectangle {
                        visible: blockRow.block.type === "divider"
                        Layout.fillWidth: true; height: 1
                        color: win.cBorder
                        Layout.topMargin: 4; Layout.bottomMargin: 4
                    }
                    Label {
                        visible: blockRow.block.type === "label"
                        text: visible ? blockRow.block.text : ""
                        color: win.cTextFaint; font.pixelSize: 10; font.bold: true
                        Layout.topMargin: 6; Layout.leftMargin: 8
                    }
                    Rectangle {
                        visible: blockRow.block.type === "item"
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: 6
                        color: itemMa.containsMouse ? win.cBgHover : "transparent"
                        Label {
                            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            text: parent.visible ? blockRow.block.label : ""
                            color: win.cText; font.pixelSize: 12
                        }
                        MouseArea {
                            id: itemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { ctxMenu.close(); blockRow.block.action(); }
                        }
                    }
                    RowLayout {
                        visible: blockRow.block.type === "swatches"
                        spacing: 6
                        Layout.leftMargin: 8; Layout.topMargin: 4; Layout.bottomMargin: 4
                        Repeater {
                            model: blockRow.block.type === "swatches" ? blockRow.block.colors : []
                            delegate: Rectangle {
                                width: 16; height: 16; radius: 8
                                color: modelData.hex
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { ctxMenu.close(); blockRow.block.onPick(modelData.id); }
                                }
                            }
                        }
                    }
                }
            }
        }
        function openWithBlocks(blocksArr, posX, posY) { blocks = blocksArr; x = posX; y = posY; open(); }
    }

    function showItemMenu(idx, pos) {
        var it = currentItems()[idx];
        var blocks = [];
        blocks.push({type:"item", label:"Renombrar", action: function(){ renameDialog.openFor(idx, it.name); }});
        blocks.push({type:"item", label:"Duplicar", action: function(){ duplicateItem(idx); }});
        if (it.type === "folder") blocks.push({type:"item", label:"Añadir a Favoritos", action: function(){ addToFavorites(idx); }});
        blocks.push({type:"label", text:"Agregar marcador"});
        blocks.push({type:"swatches", colors: tagColors, onPick: function(colorId){
            var c = null;
            for (var i = 0; i < tagColors.length; i++) if (tagColors[i].id === colorId) c = tagColors[i];
            assignTag(idx, c);
        }});
        blocks.push({type:"item", label:"Propiedades", action: function(){ propertiesDialog.openForIdx(idx); }});
        blocks.push({type:"divider"});
        blocks.push({type:"item", label:"Copiar", action: function(){ copyItem(idx); }});
        blocks.push({type:"item", label:"Cortar", action: function(){ cutItem(idx); }});
        blocks.push({type:"divider"});
        blocks.push({type:"item", label:"Mover a la papelera", action: function(){ trashItem(idx); }});
        ctxMenu.openWithBlocks(blocks, pos.x, pos.y);
    }
    function showEmptyMenu(pos) {
        var blocks = [];
        if (clipboardItem) {
            blocks.push({type:"item", label:'Pegar "' + clipboardItem.node.name + '"', action: pasteItem});
            blocks.push({type:"divider"});
        }
        blocks.push({type:"item", label:"Nueva carpeta", action: createNewFolder});
        blocks.push({type:"divider"});
        blocks.push({type:"label", text:"Ordenar por"});
        blocks.push({type:"item", label:"Nombre", action: function(){ sortItemsBy("name"); }});
        blocks.push({type:"item", label:"Tipo", action: function(){ sortItemsBy("type"); }});
        blocks.push({type:"item", label:"Tamaño", action: function(){ sortItemsBy("size"); }});
        blocks.push({type:"item", label:"Fecha", action: function(){ sortItemsBy("mod"); }});
        blocks.push({type:"divider"});
        blocks.push({type:"item", label: currentView==="grid" ? "Ver como Lista" : "Ver como Iconos", action: function(){ currentView = currentView==="grid"?"list":"grid"; }});
        ctxMenu.openWithBlocks(blocks, pos.x, pos.y);
    }
    function showSidebarMenu(pos) {
        ctxMenu.openWithBlocks([{type:"item", label:"Quitar de la barra lateral", action: function(){ flash("Elemento quitado de la barra lateral"); }}], pos.x, pos.y);
    }
    function showFavMenu(favIdx, pos) {
        ctxMenu.openWithBlocks([{type:"item", label:"Quitar de Favoritos", action: function(){ removeFavorite(favIdx); }}], pos.x, pos.y);
    }
    function showDiskMenu(pos) {
        ctxMenu.openWithBlocks([{type:"item", label:"Información", action: function(){ infoDialog.show("Disco local", ["Capacidad: 250 GB", "Formato: x86_64 · ext4"]); }}], pos.x, pos.y);
    }
    function showUsbMenuAt(pos) {
        ctxMenu.openWithBlocks([
            {type:"item", label:'Expulsar "USB Kingston"', action: function(){ flash("USB Kingston expulsado de forma segura"); }},
            {type:"item", label:"Información", action: function(){ infoDialog.show("USB Kingston", ["Capacidad: 32 GB", "Formato: FAT32 · extraíble"]); }}
        ], pos.x, pos.y);
    }

    // ---------- Diálogos ----------
    Dialog {
        id: renameDialog
        modal: true
        title: "Cambiar nombre"
        standardButtons: Dialog.Cancel | Dialog.Ok
        anchors.centerIn: parent
        property int targetIdx: -1
        background: Rectangle { color: win.cBgElevated; border.color: win.cBorder; radius: 12 }
        function openFor(idx, currentName) {
            targetIdx = idx;
            nameField.text = currentName;
            open();
            nameField.selectAll();
            nameField.forceActiveFocus();
        }
        contentItem: ColumnLayout {
            width: 260
            TextField {
                id: nameField
                Layout.fillWidth: true
                color: win.cText
                background: Rectangle { color: "#0b0b0c"; border.color: win.cBorder; radius: 8 }
                Keys.onReturnPressed: { renameDialog.accept(); }
            }
        }
        onAccepted: win.renameItem(targetIdx, nameField.text)
    }
    function renameItem(idx, newName) {
        var items = currentItems();
        if (idx >= 0 && idx < items.length && newName.trim().length > 0) items[idx].name = newName.trim();
        refreshItems();
        rebuildColumnsModel();
    }

    Dialog {
        id: propertiesDialog
        modal: true
        title: "Propiedades"
        standardButtons: Dialog.Close
        anchors.centerIn: parent
        property var node: null
        background: Rectangle { color: win.cBgElevated; border.color: win.cBorder; radius: 12 }
        function openForIdx(idx) { node = win.currentItems()[idx]; open(); }
        contentItem: ColumnLayout {
            spacing: 6
            width: 260
            Label { text: "Nombre: " + (propertiesDialog.node ? propertiesDialog.node.name : ""); color: win.cText }
            Label { text: "Tipo: " + (propertiesDialog.node ? (propertiesDialog.node.type === "folder" ? "Carpeta" : (propertiesDialog.node.ext || "Archivo")) : ""); color: win.cTextDim }
            Label { visible: propertiesDialog.node && propertiesDialog.node.type === "file"; text: "Tamaño: " + (propertiesDialog.node ? propertiesDialog.node.size : ""); color: win.cTextDim }
            Label { visible: propertiesDialog.node && propertiesDialog.node.type === "folder"; text: "Elementos: " + (propertiesDialog.node && propertiesDialog.node.children ? propertiesDialog.node.children.length : 0); color: win.cTextDim }
            Label { text: "Modificado: " + (propertiesDialog.node ? (propertiesDialog.node.mod || "—") : ""); color: win.cTextDim }
        }
    }

    Dialog {
        id: infoDialog
        modal: true
        standardButtons: Dialog.Close
        anchors.centerIn: parent
        property var infoLines: []
        background: Rectangle { color: win.cBgElevated; border.color: win.cBorder; radius: 12 }
        function show(t, lines) { title = t; infoLines = lines; open(); }
        contentItem: ColumnLayout {
            width: 240
            Repeater { model: infoDialog.infoLines; delegate: Label { text: modelData; color: win.cText } }
        }
    }

    // ---------- Atajos de teclado ----------
    Shortcut { sequence: "Ctrl+C"; onActivated: if (win.selectedIndices.length > 0) win.copyItem(win.selectedIndices[0]) }
    Shortcut { sequence: "Ctrl+X"; onActivated: if (win.selectedIndices.length > 0) win.cutItem(win.selectedIndices[0]) }
    Shortcut { sequence: "Ctrl+V"; onActivated: win.pasteItem() }
    Shortcut { sequence: "Ctrl+D"; onActivated: if (win.selectedIndices.length > 0) win.duplicateItem(win.selectedIndices[0]) }
    Shortcut { sequence: "Ctrl+A"; onActivated: win.selectAllItems() }
    Shortcut { sequence: "Delete"; onActivated: if (win.selectedIndices.length > 0) win.trashItem(win.selectedIndices[0]) }
    Shortcut { sequence: "Return"; onActivated: if (win.selectedIndices.length === 1) win.renameDialogFor(win.selectedIndices[0]) }
    function renameDialogFor(idx) { renameDialog.openFor(idx, currentItems()[idx].name); }

    // ================= INTERFAZ =================
    header: ColumnLayout {
        spacing: 0

        // ---- Barra de título / marca ----
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: win.cBgElevated
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8
                Image {
                    source: win.assetsPath + "archivos-logo.svg"
                    sourceSize.width: 20; sourceSize.height: 20
                }
                Label { text: "Archivos"; color: win.cText; font.pixelSize: 13; font.bold: true }
                Item { Layout.fillWidth: true }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: win.cBorder }
        }

        // ---- Barra de herramientas ----
        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: win.cBgElevated
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 14

                RowLayout {
                    spacing: 2
                    IconButton { iconName: "chevron-left"; enabled: win.canGoBack; onClicked: win.goBack() }
                    IconButton { iconName: "chevron-right"; enabled: win.canGoForward; onClicked: win.goForward() }
                }

                Label { text: win.currentFolder().name; color: win.cText; font.bold: true; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }

                // Switch de vista segmentado
                Rectangle {
                    Layout.preferredWidth: 116; Layout.preferredHeight: 26
                    radius: 8
                    color: "#0b0b0c"
                    border.color: win.cBorder; border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        SegButton { iconName: "view-grid"; active: win.currentView === "grid"; onClicked: win.currentView = "grid" }
                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: win.cBorder }
                        SegButton { iconName: "view-list"; active: win.currentView === "list"; onClicked: win.currentView = "list" }
                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: win.cBorder }
                        SegButton { iconName: "view-columns"; active: win.currentView === "columns"; onClicked: win.currentView = "columns" }
                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: win.cBorder }
                        SegButton { iconName: "view-gallery"; active: win.currentView === "gallery"; onClicked: win.currentView = "gallery" }
                    }
                }

                // Buscador
                Rectangle {
                    Layout.preferredWidth: 170; Layout.preferredHeight: 27
                    radius: 8
                    color: "#0b0b0c"
                    border.color: win.cBorder; border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 9; anchors.rightMargin: 9
                        spacing: 6
                        Image { source: win.assetsPath + "ui/search.svg"; sourceSize.width: 13; sourceSize.height: 13 }
                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            placeholderText: "Buscar"
                            placeholderTextColor: win.cTextFaint
                            color: win.cText
                            font.pixelSize: 12
                            background: Item {}
                            leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
                            selectByMouse: true
                            onTextChanged: win.searchQuery = text.toLowerCase()
                        }
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: win.cBorder }
        }
    }

    // ---- Botón de icono circular reutilizable (atrás/adelante) ----
    component IconButton: Rectangle {
        id: ibtn
        property string iconName: ""
        signal clicked()
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        radius: 7
        color: ibtn.enabled && ma.containsMouse ? win.cBgHover : "transparent"
        opacity: ibtn.enabled ? 1 : 0.35
        Image {
            anchors.centerIn: parent
            source: win.assetsPath + "ui/" + ibtn.iconName + (ma.containsMouse && ibtn.enabled ? "-active" : "") + ".svg"
            sourceSize.width: 15; sourceSize.height: 15
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: ibtn.clicked()
        }
    }

    // ---- Botón del switch de vista segmentado ----
    component SegButton: Item {
        id: sbtn
        property string iconName: ""
        property bool active: false
        signal clicked()
        Layout.fillWidth: true
        Layout.fillHeight: true
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 6
            color: sbtn.active ? win.cAccentSoft : "transparent"
        }
        Image {
            anchors.centerIn: parent
            source: win.assetsPath + "ui/" + sbtn.iconName + (sbtn.active ? "-active" : "") + ".svg"
            sourceSize.width: 13; sourceSize.height: 13
        }
        MouseArea { anchors.fill: parent; onClicked: sbtn.clicked() }
    }

    footer: ToolBar {
        background: Rectangle { color: win.cBgElevated; Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: win.cBorder } }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            Row {
                spacing: 4
                Repeater {
                    model: win.path
                    delegate: Row {
                        spacing: 4
                        Label { visible: index > 0; text: "›"; color: win.cTextFaint; font.pixelSize: 11 }
                        Label {
                            text: modelData.name
                            color: index === win.path.length - 1 ? win.cText : win.cTextDim
                            font.pixelSize: 11
                            MouseArea {
                                anchors.fill: parent
                                enabled: index < win.path.length - 1
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: win.navigateToCrumb(index)
                            }
                        }
                    }
                }
            }
            Item { Layout.fillWidth: true }
            Label { text: win.statusText; color: win.cTextDim; font.pixelSize: 11 }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- Barra lateral ----------
        Rectangle {
            id: sidebarPanel
            Layout.preferredWidth: 210
            Layout.fillHeight: true
            color: win.cBgSidebar
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: win.cBorder }

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                ColumnLayout {
                    width: parent.width
                    spacing: 2

                    Label { text: "FAVORITOS"; color: win.cTextFaint; font.pixelSize: 10; font.bold: true; Layout.topMargin: 2 }
                    Repeater {
                        model: win.favRows
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 7
                            color: win.activeSidebarKey === modelData.key ? win.cAccent : (rowMa.containsMouse ? win.cBgHover : "transparent")
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 8
                                spacing: 9
                                Image {
                                    source: win.assetsPath + "ui/" + modelData.key + (win.activeSidebarKey === modelData.key ? "-active" : "") + ".svg"
                                    sourceSize.width: 16; sourceSize.height: 16
                                }
                                Label {
                                    text: modelData.label
                                    color: win.activeSidebarKey === modelData.key ? "#ffffff" : win.cText
                                    font.pixelSize: 13
                                }
                            }
                            MouseArea {
                                id: rowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: {
                                    if (mouse.button === Qt.RightButton) win.showSidebarMenu(mapToItem(null, mouse.x, mouse.y));
                                    else win.goToFolder(modelData.key);
                                }
                            }
                        }
                    }
                    Repeater {
                        model: win.favorites
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 7
                            color: favMa.containsMouse ? win.cBgHover : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 8
                                spacing: 9
                                Image { source: win.assetsPath + "ui/documentos.svg"; sourceSize.width: 16; sourceSize.height: 16 }
                                Label { text: modelData.name; color: win.cText; font.pixelSize: 13 }
                            }
                            MouseArea {
                                id: favMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.RightButton
                                onClicked: win.showFavMenu(index, mapToItem(null, mouse.x, mouse.y))
                            }
                        }
                    }

                    Label { text: "UBICACIONES"; color: win.cTextFaint; font.pixelSize: 10; font.bold: true; Layout.topMargin: 12 }
                    Rectangle {
                        Layout.fillWidth: true; height: 30; radius: 7
                        color: diskMa.containsMouse ? win.cBgHover : "transparent"
                        Image { id: diskIcon; anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; source: win.assetsPath + "ui/disk.svg"; sourceSize.width: 16; sourceSize.height: 16 }
                        Label { anchors.left: diskIcon.right; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: "Disco local"; color: win.cText; font.pixelSize: 12 }
                        Label { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "250 GB"; color: win.cTextFaint; font.pixelSize: 11 }
                        MouseArea {
                            id: diskMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: win.showDiskMenu(mapToItem(null, mouse.x, mouse.y))
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 30; radius: 7
                        color: usbMa.containsMouse ? win.cBgHover : "transparent"
                        Image { id: usbIcon; anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; source: win.assetsPath + "ui/usb.svg"; sourceSize.width: 16; sourceSize.height: 16 }
                        Label { anchors.left: usbIcon.right; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: "USB Kingston"; color: win.cText; font.pixelSize: 12 }
                        Label { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "32 GB"; color: win.cTextFaint; font.pixelSize: 11 }
                        MouseArea {
                            id: usbMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: win.showUsbMenuAt(mapToItem(null, mouse.x, mouse.y))
                        }
                    }

                    Label { text: "ETIQUETAS"; visible: win.usedTagColors().length > 0; color: win.cTextFaint; font.pixelSize: 10; font.bold: true; Layout.topMargin: 12 }
                    Repeater {
                        model: win.usedTagColors()
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            spacing: 8
                            Rectangle { width: 10; height: 10; radius: 5; color: modelData.hex }
                            Label { text: modelData.label; color: win.cText; font.pixelSize: 12 }
                            Item { Layout.fillWidth: true }
                            Label { text: win.tagCount(modelData.id); color: win.cTextFaint; font.pixelSize: 11 }
                        }
                    }
                }
            }
        }

        // ---------- Contenido ----------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: win.cBg

            GridView {
                id: gridView
                visible: win.currentView === "grid"
                anchors.fill: parent
                anchors.margins: 18
                cellWidth: 100; cellHeight: 108
                clip: true
                model: itemsModel

                MouseArea {
                    id: emptyMa
                    anchors.fill: parent
                    z: -1
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    property real startX: 0
                    property real startY: 0
                    property bool dragging: false
                    onPressed: { startX = mouse.x; startY = mouse.y; dragging = false; }
                    onPositionChanged: {
                        if (pressed && (mouse.buttons & Qt.LeftButton)) {
                            if (!dragging && (Math.abs(mouse.x - startX) > 4 || Math.abs(mouse.y - startY) > 4)) dragging = true;
                            if (dragging) {
                                var x1 = Math.min(startX, mouse.x), x2 = Math.max(startX, mouse.x);
                                var y1 = Math.min(startY, mouse.y), y2 = Math.max(startY, mouse.y);
                                marqueeRect.x = x1; marqueeRect.y = y1;
                                marqueeRect.width = x2 - x1; marqueeRect.height = y2 - y1;
                                marqueeRect.visible = true;
                                win.marqueeSelect(x1, y1, x2, y2, gridView.contentY, gridView.width);
                            }
                        }
                    }
                    onReleased: {
                        if (dragging) { dragging = false; marqueeRect.visible = false; return; }
                        if (mouse.button === Qt.RightButton) win.showEmptyMenu(mapToItem(null, mouse.x, mouse.y));
                        else win.deselectAll();
                    }
                }
                Rectangle {
                    id: marqueeRect
                    visible: false
                    z: 20
                    color: Qt.rgba(0.72, 0.26, 0.24, 0.14)
                    border.color: win.cAccent
                    border.width: 1
                }

                delegate: Rectangle {
                    width: 96; height: 104
                    radius: 9
                    visible: win.searchQuery === "" || iName.toLowerCase().indexOf(win.searchQuery) !== -1
                    property bool selected: win.selectedIndices.indexOf(iIdx) !== -1
                    property bool isCut: win.clipboardItem && win.clipboardItem.mode === "cut" && win.clipboardItem.idx === iIdx
                    opacity: isCut ? 0.4 : 1
                    color: selected ? win.cAccentSoft : (tileMa.containsMouse ? "#ffffff0c" : "transparent")

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 54
                            Image {
                                anchors.centerIn: parent
                                source: iType === "folder" ? (win.assetsPath + "folder-" + iIcon + ".svg") : (win.assetsPath + "file-generic.svg")
                                sourceSize.width: iType === "folder" ? 60 : 40
                                sourceSize.height: iType === "folder" ? 46 : 52
                            }
                            Rectangle {
                                visible: iType === "file" && iExt !== ""
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.bottomMargin: 4
                                color: extColor(iExt)
                                radius: 3
                                height: 12
                                width: extLabel.implicitWidth + 6
                                Label { id: extLabel; anchors.centerIn: parent; text: iExt; color: "#ffffff"; font.pixelSize: 7; font.bold: true }
                            }
                        }
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: iName
                            color: win.cText
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            Layout.maximumWidth: 90
                            elide: Text.ElideNone
                            padding: 2
                            background: Rectangle { color: selected ? win.cAccent : "transparent"; radius: 4 }
                        }
                    }
                    MouseArea {
                        id: tileMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        property bool draggingOut: false
                        onPressed: { draggingOut = false; }
                        onPositionChanged: {
                            if (pressed && (mouse.buttons & Qt.LeftButton) && iType === "folder") {
                                if (!draggingOut && (Math.abs(mouse.x - width / 2) > 40 || Math.abs(mouse.y - height / 2) > 40)) draggingOut = true;
                            }
                        }
                        onReleased: {
                            if (mouse.button === Qt.RightButton) { win.showItemMenu(iIdx, mapToItem(null, mouse.x, mouse.y)); draggingOut = false; return; }
                            if (draggingOut) {
                                var gp = mapToItem(null, mouse.x, mouse.y);
                                if (win.pointInSidebar(gp.x, gp.y)) win.addToFavorites(iIdx);
                                draggingOut = false;
                                return;
                            }
                            win.selectItem(iIdx, mouse.modifiers);
                        }
                        onDoubleClicked: iType === "folder" ? win.enterFolder(iIdx) : propertiesDialog.openForIdx(iIdx)
                    }
                }
            }

            ListView {
                id: listView
                visible: win.currentView === "list"
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                model: itemsModel

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: {
                        if (mouse.button === Qt.RightButton) win.showEmptyMenu(mapToItem(null, mouse.x, mouse.y));
                        else win.deselectAll();
                    }
                }

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 30
                    radius: 6
                    visible: win.searchQuery === "" || iName.toLowerCase().indexOf(win.searchQuery) !== -1
                    property bool selected: win.selectedIndices.indexOf(iIdx) !== -1
                    color: selected ? win.cAccentSoft : (rowMa2.containsMouse ? "#ffffff0c" : "transparent")
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Image {
                            source: iType === "folder" ? (win.assetsPath + "folder-" + iIcon + ".svg") : (win.assetsPath + "file-generic.svg")
                            sourceSize.width: iType === "folder" ? 26 : 18
                            sourceSize.height: iType === "folder" ? 21 : 24
                        }
                        Label { text: iName; color: win.cText; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label { text: iMod !== "" ? iMod : "—"; color: win.cTextDim; font.pixelSize: 11; Layout.preferredWidth: 100 }
                        Label { text: iSize !== "" ? iSize : (iType === "folder" ? "—" : ""); color: win.cTextDim; font.pixelSize: 11; Layout.preferredWidth: 80 }
                    }
                    MouseArea {
                        id: rowMa2
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: {
                            if (mouse.button === Qt.RightButton) { win.showItemMenu(iIdx, mapToItem(null, mouse.x, mouse.y)); return; }
                            win.selectItem(iIdx, mouse.modifiers);
                        }
                        onDoubleClicked: iType === "folder" ? win.enterFolder(iIdx) : propertiesDialog.openForIdx(iIdx)
                    }
                }
            }

            // ---------- Vista en columnas ----------
            Flickable {
                id: colsFlick
                visible: win.currentView === "columns"
                anchors.fill: parent
                contentWidth: colsRow.width
                clip: true
                Row {
                    id: colsRow
                    height: colsFlick.height
                    Repeater {
                        model: win.columnsModel
                        delegate: Rectangle {
                            id: colWrap
                            property var colData: modelData
                            property int colIdx: index
                            width: 200
                            height: colsFlick.height
                            color: "transparent"
                            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: win.cBorder }
                            ListView {
                                anchors.fill: parent
                                anchors.margins: 6
                                clip: true
                                model: colWrap.colData.children
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: 27
                                    radius: 6
                                    property bool isActive: modelData.name === colWrap.colData.activeName
                                    color: isActive ? win.cAccent : (colRowMa.containsMouse ? win.cBgHover : "transparent")
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6; anchors.rightMargin: 6
                                        spacing: 6
                                        Image {
                                            source: modelData.type === "folder" ? (win.assetsPath + "folder-" + (modelData.icon || "generic") + ".svg") : (win.assetsPath + "file-generic.svg")
                                            sourceSize.width: modelData.type === "folder" ? 20 : 13
                                            sourceSize.height: modelData.type === "folder" ? 16 : 17
                                        }
                                        Label { text: modelData.name; color: isActive ? "#ffffff" : win.cText; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                                        Label { visible: modelData.type === "folder"; text: "›"; color: isActive ? "#ffffff" : win.cTextFaint; font.pixelSize: 12 }
                                    }
                                    MouseArea {
                                        id: colRowMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: win.columnItemClicked(colWrap.colIdx, index)
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: win.columnPreviewNode !== null
                        width: 220
                        height: colsFlick.height
                        color: "transparent"
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 10
                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 70; Layout.preferredHeight: 56
                                Image {
                                    anchors.centerIn: parent
                                    source: win.assetsPath + "file-generic.svg"
                                    sourceSize.width: 50; sourceSize.height: 64
                                }
                                Rectangle {
                                    visible: win.columnPreviewNode !== null
                                    anchors.bottom: parent.bottom; anchors.right: parent.right
                                    color: win.extColor(win.columnPreviewNode ? win.columnPreviewNode.ext : "")
                                    radius: 3; height: 12
                                    width: pvExtLbl.implicitWidth + 6
                                    Label { id: pvExtLbl; anchors.centerIn: parent; text: win.columnPreviewNode ? win.columnPreviewNode.ext : ""; color: "#ffffff"; font.pixelSize: 7; font.bold: true }
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                text: win.columnPreviewNode ? win.columnPreviewNode.name : ""
                                color: win.cText; font.pixelSize: 13; font.bold: true
                                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                            }
                            Label { text: "Tamaño: " + (win.columnPreviewNode ? (win.columnPreviewNode.size || "—") : ""); color: win.cTextDim; font.pixelSize: 11 }
                            Label { text: "Modificado: " + (win.columnPreviewNode ? (win.columnPreviewNode.mod || "—") : ""); color: win.cTextDim; font.pixelSize: 11 }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }

            // ---------- Vista galería ----------
            ColumnLayout {
                visible: win.currentView === "gallery"
                anchors.fill: parent
                spacing: 0
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 14
                        visible: win.gallerySelNode() !== null
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 180; Layout.preferredHeight: 150
                            Image {
                                anchors.centerIn: parent
                                source: win.galleryIconSource()
                                sourceSize.width: win.gallerySelType() === "folder" ? 170 : 120
                                sourceSize.height: win.gallerySelType() === "folder" ? 136 : 156
                            }
                            Rectangle {
                                visible: win.gallerySelType() === "file" && win.gallerySelExt() !== ""
                                anchors.bottom: parent.bottom; anchors.right: parent.right
                                anchors.bottomMargin: 4
                                color: win.extColor(win.gallerySelExt())
                                radius: 3; height: 14
                                width: galExtLbl.implicitWidth + 8
                                Label { id: galExtLbl; anchors.centerIn: parent; text: win.gallerySelExt(); color: "#ffffff"; font.pixelSize: 8; font.bold: true }
                            }
                        }
                        Label { Layout.alignment: Qt.AlignHCenter; text: win.gallerySelName(); color: win.cText; font.pixelSize: 14; font.bold: true }
                        Label { Layout.alignment: Qt.AlignHCenter; text: win.galleryMeta(); color: win.cTextDim; font.pixelSize: 11 }
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: win.gallerySelNode() === null
                        text: "Esta carpeta está vacía"
                        color: win.cTextFaint
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84
                    color: "transparent"
                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: win.cBorder }
                    ListView {
                        anchors.fill: parent
                        anchors.margins: 10
                        orientation: ListView.Horizontal
                        spacing: 8
                        clip: true
                        model: itemsModel
                        delegate: Rectangle {
                            width: 56; height: 56; radius: 8
                            property bool isSel: win.gallerySelected === iIdx
                            color: isSel ? win.cAccentSoft : (galMa.containsMouse ? win.cBgHover : "transparent")
                            border.color: isSel ? win.cAccent : "transparent"
                            border.width: isSel ? 1.5 : 0
                            Image {
                                anchors.centerIn: parent
                                source: iType === "folder" ? (win.assetsPath + "folder-" + iIcon + ".svg") : (win.assetsPath + "file-generic.svg")
                                sourceSize.width: iType === "folder" ? 40 : 28
                                sourceSize.height: iType === "folder" ? 32 : 36
                            }
                            MouseArea { id: galMa; anchors.fill: parent; hoverEnabled: true; onClicked: win.gallerySelected = iIdx }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        refreshItems();
        rebuildColumnsModel();
        gallerySelected = currentItems().length ? 0 : null;
    }
}
