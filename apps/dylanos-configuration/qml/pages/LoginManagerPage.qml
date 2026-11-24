import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import org.dylanos.configuration

// Pantalla de acceso: todo el DylanOS Login Manager desde aquí.
//
// No hay ninguna opción que exija terminal: fondo, composición, tamaños,
// widgets, atajos (cuatro como máximo), Crimson Glass, color y variantes se
// cambian en esta página. La vista previa es una captura del greeter real, así
// que lo que se ve aquí es exactamente lo que aparece al arrancar.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property string tab: "Apariencia"
    property var valores: LoginManager.settings
    property var widgets: LoginManager.widgets
    property var atajos: LoginManager.shortcuts
    property var variantes: LoginManager.variants
    property var fondos: []
    property string fondoActual: LoginManager.backgroundPath
    property string vistaPrevia: ""
    property string aviso: ""
    property bool avisoError: false

    readonly property var comp: valores.composicion || ({})
    readonly property var apa: valores.apariencia || ({})
    readonly property var elegidos: valores.widgets || ({})
    readonly property var atajosActivos: (valores.atajos || ({})).activos || []
    readonly property int maxAtajos: LoginManager.maximumShortcuts

    function sincronizar() {
        valores = LoginManager.settings
        fondoActual = LoginManager.backgroundPath
    }
    function refrescarFondos() {
        fondos = System.wallpapers()
    }
    Component.onCompleted: Qt.callLater(function () { refrescarFondos(); mostrarAviso("") })

    Connections {
        target: LoginManager
        function onSettingsChanged() { root.sincronizar() }
        function onActionFailed(mensaje) { root.mostrarAviso(mensaje, true) }
        function onActionDone(mensaje) { root.mostrarAviso(mensaje, false) }
        function onPreviewReady(ruta) { root.vistaPrevia = ruta + "?v=" + Date.now() }
    }

    function mostrarAviso(texto, error) {
        aviso = texto
        avisoError = error === true
        if (texto !== "")
            toastTimer.restart()
    }
    Timer {
        id: toastTimer
        interval: 5000
        onTriggered: root.aviso = ""
    }

    function aplicar(ruta, valor) {
        LoginManager.setValue(ruta, valor)
    }
    function estaElegido(id) {
        const izq = elegidos.columna_izquierda || []
        const der = elegidos.columna_derecha || []
        return izq.indexOf(id) >= 0 || der.indexOf(id) >= 0
    }
    function atajoActivo(id) {
        return atajosActivos.indexOf(id) >= 0
    }
    function posicionEtiqueta(valor) {
        if (valor === "espejo") return "Espejo"
        if (valor === "solo-centro") return "Solo centro"
        return "Clásica"
    }
    function varianteActual() {
        const v = comp.variante || "completa"
        return v.charAt(0).toUpperCase() + v.slice(1)
    }

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        TabsBar {
            width: parent.width
            value: root.tab
            tabs: ["Apariencia", "Composición", "Widgets", "Atajos", "Vista previa"]
            onPicked: function (t) { root.tab = t }
        }

        // Aviso de la última acción: éxito o error real del sistema.
        Rectangle {
            width: parent.width
            height: root.aviso === "" ? 0 : 44
            visible: root.aviso !== ""
            radius: Theme.radiusControl
            color: root.avisoError ? "#3a1116" : Theme.c.surface
            border.width: 1
            border.color: root.avisoError ? "#ff5274" : Theme.c.border
            Text {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: Text.AlignVCenter
                text: root.aviso
                font.pixelSize: 13
                color: root.avisoError ? "#ff8fa3" : Theme.c.text
                elide: Text.ElideRight
            }
        }

        // ------------------------------------------------------- apariencia
        Column {
            visible: root.tab === "Apariencia"
            width: parent.width
            spacing: 16

            Text { text: "Variante"; font.pixelSize: 18; color: Theme.c.text }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "La variante cambia de golpe los widgets y la composición. Después puedes ajustar cualquier cosa a mano."
                font.pixelSize: 12.5
                color: Theme.c.textDim
            }
            Row {
                width: parent.width
                spacing: 12
                Repeater {
                    model: root.variantes
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 24) / 3
                        height: 96
                        radius: Theme.radiusCard
                        color: (root.comp.variante || "completa") === modelData.id
                               ? Theme.c.surfaceHigh : Theme.c.surface
                        border.width: 1
                        border.color: (root.comp.variante || "completa") === modelData.id
                                      ? Theme.accent : Theme.c.border
                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6
                            Text {
                                text: modelData.nombre
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.c.text
                            }
                            Text {
                                width: parent.width
                                text: modelData.descripcion
                                font.pixelSize: 11.5
                                color: Theme.c.textDim
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                maximumLineCount: 3
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LoginManager.applyVariant(modelData.id)
                        }
                    }
                }
            }

            Text { text: "Fondo de pantalla"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    icon: "image"
                    iconColor: Theme.accent
                    title: "Fondo actual"
                    desc: root.fondoActual
                    Row {
                        spacing: 10
                        ActionButton {
                            text: "Elegir imagen…"
                            variant: "primary"
                            onClicked: selectorFondo.open()
                        }
                        ActionButton {
                            text: "Del sistema"
                            onClicked: root.refrescarFondos()
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    icon: "layout-grid"
                    iconColor: Theme.accent
                    title: "Fondos instalados"
                    desc: "Elige uno del catálogo de DylanOS"
                    last: true
                    DSelect {
                        width: 260
                        value: "Elegir…"
                        options: root.fondos.map(function (f) { return f.name })
                        onPicked: function (nombre) {
                            const elegido = root.fondos.find(function (f) { return f.name === nombre })
                            if (elegido)
                                LoginManager.setBackground(elegido.path)
                        }
                    }
                }
            }

            Text { text: "Color"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    icon: "palette"
                    iconColor: Theme.accent
                    title: "Usar el acento de DylanOS"
                    desc: "El login toma el color de énfasis de Configuración del sistema"
                    DToggle {
                        on: root.apa.usar_acento_del_sistema !== false
                        onToggled: function (v) { root.aplicar("apariencia.usar_acento_del_sistema", v) }
                    }
                }
                RowItem {
                    width: parent.width
                    icon: "droplet"
                    iconColor: Theme.accent
                    title: "Color propio del login"
                    desc: "Solo se usa si desactivas el acento del sistema"
                    last: true
                    Row {
                        spacing: 8
                        Repeater {
                            model: ["#DC143C", "#FF4565", "#14C8DC", "#8B5CF6", "#22C55E", "#F59E0B"]
                            delegate: Rectangle {
                                required property var modelData
                                width: 30
                                height: 30
                                radius: 15
                                color: modelData
                                border.width: 2
                                border.color: (root.apa.color_primario || "").toLowerCase()
                                              === modelData.toLowerCase() ? Theme.c.text : "transparent"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.aplicar("apariencia.color_primario", modelData)
                                }
                            }
                        }
                    }
                }
            }

            Text { text: "Material"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    icon: "sparkles"
                    iconColor: Theme.accent
                    title: "Crimson Glass"
                    desc: "Vidrio esmerilado en las tarjetas del login. Al apagarlo quedan superficies opacas."
                    last: true
                    DToggle {
                        on: root.apa.crimson_glass !== false
                        onToggled: function (v) { root.aplicar("apariencia.crimson_glass", v) }
                    }
                }
            }

            ActionButton {
                text: "Restablecer al prototipo"
                onClicked: LoginManager.resetToPrototype()
            }
        }

        // ------------------------------------------------------ composición
        Column {
            visible: root.tab === "Composición"
            width: parent.width
            spacing: 16

            Text { text: "Distribución"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    icon: "columns"
                    iconColor: Theme.accent
                    title: "Posición de los paneles"
                    desc: "Clásica: tarjetas a los dos lados. Espejo: intercambiadas. Solo centro: sin columnas."
                    last: true
                    DSelect {
                        width: 200
                        value: root.posicionEtiqueta(root.comp.posicion_paneles || "clasica")
                        options: ["Clásica", "Espejo", "Solo centro"]
                        onPicked: function (texto) {
                            const mapa = { "Clásica": "clasica", "Espejo": "espejo",
                                           "Solo centro": "solo-centro" }
                            root.aplicar("composicion.posicion_paneles", mapa[texto])
                        }
                    }
                }
            }

            Text { text: "Tamaños"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    icon: "clock"
                    iconColor: Theme.accent
                    title: "Reloj"
                    desc: Math.round((root.comp.tamano_reloj || 1) * 100) + " % del tamaño del prototipo"
                    DSlider {
                        width: 220
                        minimum: 60
                        maximum: 160
                        value: Math.round((root.comp.tamano_reloj || 1) * 100)
                        onMoved: function (v) { root.aplicar("composicion.tamano_reloj", v / 100) }
                    }
                }
                RowItem {
                    width: parent.width
                    icon: "user"
                    iconColor: Theme.accent
                    title: "Bloque de acceso"
                    desc: Math.round((root.comp.tamano_bloque_acceso || 1) * 100) + " % del tamaño del prototipo"
                    last: true
                    DSlider {
                        width: 220
                        minimum: 60
                        maximum: 160
                        value: Math.round((root.comp.tamano_bloque_acceso || 1) * 100)
                        onMoved: function (v) { root.aplicar("composicion.tamano_bloque_acceso", v / 100) }
                    }
                }
            }

            Text { text: "Datos del login"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    icon: "cloud-sun"
                    iconColor: Theme.accent
                    title: "Ubicación del clima"
                    desc: "Sin coordenadas, el widget de clima no aparece. Se usa open-meteo, sin clave."
                    Row {
                        spacing: 8
                        TextField {
                            id: campoLat
                            width: 110
                            placeholderText: "Latitud"
                            text: (root.valores.clima || ({})).latitud !== null
                                  && (root.valores.clima || ({})).latitud !== undefined
                                  ? String((root.valores.clima || ({})).latitud) : ""
                            onEditingFinished: if (text !== "")
                                root.aplicar("clima.latitud", parseFloat(text))
                        }
                        TextField {
                            id: campoLon
                            width: 110
                            placeholderText: "Longitud"
                            text: (root.valores.clima || ({})).longitud !== null
                                  && (root.valores.clima || ({})).longitud !== undefined
                                  ? String((root.valores.clima || ({})).longitud) : ""
                            onEditingFinished: if (text !== "")
                                root.aplicar("clima.longitud", parseFloat(text))
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    icon: "calendar-days"
                    iconColor: Theme.accent
                    title: "Calendario (.ics)"
                    desc: "Archivo local del que se lee el próximo evento"
                    last: true
                    Row {
                        spacing: 10
                        Text {
                            width: 180
                            text: (root.valores.agenda || ({})).ics || "Sin archivo"
                            font.pixelSize: 12
                            color: Theme.c.textDim
                            elide: Text.ElideMiddle
                        }
                        ActionButton {
                            text: "Elegir…"
                            onClicked: selectorAgenda.open()
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------- widgets
        Column {
            visible: root.tab === "Widgets"
            width: parent.width
            spacing: 12

            Text { text: "Widgets del login"; font.pixelSize: 18; color: Theme.c.text }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Cada widget declara de dónde salen sus datos. Si ese dato no existe en el equipo, el widget no se pinta: no se rellena con valores de ejemplo."
                font.pixelSize: 12.5
                color: Theme.c.textDim
            }

            GroupBox {
                width: parent.width
                Repeater {
                    model: root.widgets
                    delegate: RowItem {
                        required property var modelData
                        width: parent.width
                        last: index === root.widgets.length - 1
                        icon: modelData.columna === "derecha" ? "panel-right" : "panel-left"
                        iconColor: Theme.accent
                        title: modelData.nombre
                        desc: modelData.fuente + " · si falta: " + modelData.sinDatos
                        DToggle {
                            on: root.estaElegido(modelData.id)
                            onToggled: function (v) {
                                LoginManager.setWidgetEnabled(modelData.id, v)
                            }
                        }
                    }
                }
            }
        }

        // ----------------------------------------------------------- atajos
        Column {
            visible: root.tab === "Atajos"
            width: parent.width
            spacing: 12

            Text { text: "Atajos del login"; font.pixelSize: 18; color: Theme.c.text }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "La rejilla del prototipo tiene cuatro huecos: " + root.atajosActivos.length
                      + " de " + root.maxAtajos + " en uso. Cada atajo ejecuta una acción real."
                font.pixelSize: 12.5
                color: root.atajosActivos.length >= root.maxAtajos ? Theme.accent : Theme.c.textDim
            }

            GroupBox {
                width: parent.width
                Repeater {
                    model: root.atajos
                    delegate: RowItem {
                        required property var modelData
                        width: parent.width
                        last: index === root.atajos.length - 1
                        icon: "zap"
                        iconColor: Theme.accent
                        title: modelData.nombre
                        desc: modelData.descripcion + " · " + modelData.fuente
                        DToggle {
                            on: root.atajoActivo(modelData.id)
                            onToggled: function (v) {
                                if (!LoginManager.setShortcutEnabled(modelData.id, v) && v)
                                    root.mostrarAviso("El login admite " + root.maxAtajos
                                                      + " atajos como máximo", true)
                            }
                        }
                    }
                }
            }
        }

        // ----------------------------------------------------- vista previa
        Column {
            visible: root.tab === "Vista previa"
            width: parent.width
            spacing: 12

            Text { text: "Vista previa real"; font.pixelSize: 18; color: Theme.c.text }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Es una captura del propio greeter con la configuración actual y los datos de este equipo, no un dibujo aparte."
                font.pixelSize: 12.5
                color: Theme.c.textDim
            }

            Rectangle {
                width: parent.width
                height: 380
                radius: Theme.radiusCard
                color: Theme.c.surface
                border.width: 1
                border.color: Theme.c.border
                clip: true

                Image {
                    id: captura
                    anchors.fill: parent
                    anchors.margins: 1
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    source: root.vistaPrevia
                    visible: root.vistaPrevia !== ""
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.vistaPrevia === ""
                    text: "Pulsa «Generar vista previa» para ver el login como está ahora"
                    font.pixelSize: 13
                    color: Theme.c.textDim
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            Row {
                spacing: 10
                ActionButton {
                    text: "Generar vista previa"
                    variant: "primary"
                    onClicked: {
                        root.mostrarAviso("Generando la vista previa del login…", false)
                        LoginManager.capturePreview("/tmp/dylanos-login-preview.png")
                    }
                }
                ActionButton {
                    text: "Abrir el login en una ventana"
                    onClicked: System.exec("/usr/bin/dylanos-login-greeter",
                                           ["--preview", "--size", "1440x960"])
                }
            }
        }
    }

    FileDialog {
        id: selectorFondo
        title: "Elegir el fondo de la pantalla de acceso"
        nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: LoginManager.setBackground(selectedFile.toString().replace("file://", ""))
    }

    FileDialog {
        id: selectorAgenda
        title: "Elegir el calendario (.ics)"
        nameFilters: ["Calendario (*.ics)", "Todos los archivos (*)"]
        onAccepted: root.aplicar("agenda.ics",
                                 selectedFile.toString().replace("file://", ""))
    }
}
