import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import org.dylanos.configuration

// DylanOS Login Manager: todo el login se personaliza desde aquí.
//
// No hay ninguna opción que exija terminal ni herramientas externas: fondo,
// composición, tamaños, widgets, atajos (4 como máximo), Crimson Glass y
// colores se guardan en /etc/dylanos/login-manager.json, que es lo que lee el
// greeter. La vista previa es una captura real del propio greeter.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property string tab: "Apariencia"
    property var values: LoginManager.settings
    property var effectiveValues: LoginManager.effective
    property var atajosCatalogo: LoginManager.shortcutCatalog()
    property var widgetsCatalogo: LoginManager.widgetCatalog()
    property var fondos: LoginManager.wallpapers()
    property var seleccionAtajos: values.atajos ? (values.atajos.activos || []) : []
    property string mensajeError: ""
    property bool generandoVista: false

    function opcion(seccion, clave) {
        var bloque = root.values[seccion]
        return bloque ? bloque[clave] : undefined
    }
    function guardar(seccion, clave, valor) {
        if (LoginManager.setOption(seccion, clave, valor)) {
            root.mensajeError = ""
            root.refrescar()
        } else {
            root.mensajeError = "No se pudo guardar el ajuste"
        }
    }
    function refrescar() {
        root.values = LoginManager.settings
        root.effectiveValues = LoginManager.effective
        root.seleccionAtajos = root.values.atajos ? (root.values.atajos.activos || []) : []
    }
    function alternarAtajo(id) {
        var lista = root.seleccionAtajos.slice()
        var posicion = lista.indexOf(id)
        if (posicion >= 0) {
            lista.splice(posicion, 1)
        } else {
            if (lista.length >= 4) {
                root.mensajeError = "El login admite 4 atajos como máximo. Quita uno para añadir otro."
                return
            }
            lista.push(id)
        }
        if (LoginManager.setShortcuts(lista)) {
            root.mensajeError = ""
            root.refrescar()
        }
    }
    function estaActivo(id) {
        return root.seleccionAtajos.indexOf(id) >= 0
    }
    function nombreAtajo(id) {
        for (var i = 0; i < root.atajosCatalogo.length; i++)
            if (root.atajosCatalogo[i].id === id)
                return root.atajosCatalogo[i].nombre
        return id
    }
    function actualizarVista() {
        root.generandoVista = true
        var ok = LoginManager.refreshPreview(root.values)
        root.generandoVista = false
        if (!ok)
            root.mensajeError = "La vista previa no se pudo generar; el login mantiene la configuración guardada."
    }

    function listaRecordatorios() {
        var lista = root.values.recordatorios
        if (!lista || !lista.length) return []
        var salida = []
        for (var i = 0; i < lista.length; i++) {
            var entrada = lista[i]
            if (typeof entrada === "string") salida.push({ texto: entrada, hecho: false })
            else if (entrada && entrada.texto) salida.push({ texto: entrada.texto, hecho: !!entrada.hecho })
        }
        return salida
    }
    function guardarRecordatorios(lista) {
        if (LoginManager.setRecordatorios(lista)) {
            root.mensajeError = ""
            root.refrescar()
        }
    }
    function etiquetaPosicion(valor) {
        if (valor === "centrada") return "Centrada"
        if (valor === "izquierda") return "Izquierda"
        return "Clásica"
    }
    function valorPosicion(etiqueta) {
        if (etiqueta === "Centrada") return "centrada"
        if (etiqueta === "Izquierda") return "izquierda"
        return "clasica"
    }

    Component.onCompleted: refrescar()

    Connections {
        target: LoginManager
        function onSettingsChanged() { root.refrescar() }
        function onError(mensaje) { root.mensajeError = mensaje }
    }

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        // --- Cabecera: estado real del login -----------------------------
        Rectangle {
            width: parent.width
            height: 132
            radius: 24
            color: Qt.rgba(Theme.glassTint.r, Theme.glassTint.g, Theme.glassTint.b, 0.78)
            border.width: 1
            border.color: Qt.rgba(Theme.glassBorder.r, Theme.glassBorder.g, Theme.glassBorder.b, 0.38)

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                height: 1
                color: Qt.rgba(Theme.glassSpecular.r, Theme.glassSpecular.g, Theme.glassSpecular.b, 0.32)
            }

            Row {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                Image {
                    width: 92
                    height: 92
                    anchors.verticalCenter: parent.verticalCenter
                    source: root.values.apariencia
                            ? "file://" + root.values.apariencia.fondo_seleccionado : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.c.border
                    }
                }

                Column {
                    width: parent.width - 132
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        text: "Pantalla de acceso"
                        color: Theme.c.text
                        font.pixelSize: 23
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: LoginManager.available
                              ? "DylanOS Login Manager está activo. Lo que cambies aquí se aplica al siguiente bloqueo o arranque."
                              : "El login manager no está instalado en este sistema; los cambios se guardan para cuando lo esté."
                        color: Theme.c.textDim
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                    Row {
                        spacing: 8
                        BadgePill {
                            text: root.seleccionAtajos.length + " / 4 atajos"
                            tone: root.seleccionAtajos.length >= 4 ? "#FEBC2E" : "#58D68D"
                        }
                        BadgePill {
                            text: root.effectiveValues.crimsonGlass ? "Crimson Glass activo" : "Crimson Glass desactivado"
                            tone: root.effectiveValues.crimsonGlass ? "#58D68D" : "#B3B3B3"
                        }
                    }
                }
            }
        }

        TabsBar {
            width: parent.width
            value: root.tab
            tabs: ["Apariencia", "Composición", "Datos", "Atajos", "Widgets", "Vista previa"]
            onPicked: function (value) { root.tab = value }
        }

        // --- Aviso de error real ----------------------------------------
        Rectangle {
            width: parent.width
            height: root.mensajeError.length > 0 ? 44 : 0
            visible: root.mensajeError.length > 0
            radius: 12
            color: Qt.rgba(0.87, 0.08, 0.24, 0.14)
            border.width: 1
            border.color: Qt.rgba(0.87, 0.08, 0.24, 0.45)
            Text {
                anchors.fill: parent
                anchors.leftMargin: 14
                verticalAlignment: Text.AlignVCenter
                text: root.mensajeError
                color: Theme.c.text
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }

        // --- Apariencia --------------------------------------------------
        Column {
            visible: root.tab === "Apariencia"
            width: parent.width
            spacing: 16

            SectionTitle { text: "Fondo de pantalla" }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    title: "Imagen de fondo"
                    desc: "Se copia al sistema para que el login pueda leerla antes de iniciar sesión"
                    ActionButton {
                        text: "Ver fondos del sistema"
                        onClicked: root.tab = "Apariencia"
                    }
                }
                Row {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: root.fondos.slice(0, 6)
                        delegate: Item {
                            required property var modelData
                            readonly property string rutaFondo: modelData.ruta
                            width: 132
                            height: 84
                            Image {
                                anchors.fill: parent
                                source: "file://" + rutaFondo
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: "transparent"
                                border.width: root.values.apariencia &&
                                              root.values.apariencia.fondo_seleccionado === rutaFondo ? 2 : 1
                                border.color: root.values.apariencia &&
                                              root.values.apariencia.fondo_seleccionado === rutaFondo
                                              ? Theme.accent : Theme.c.border
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (LoginManager.setWallpaper(rutaFondo)) {
                                        root.mensajeError = ""
                                        root.refrescar()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SectionTitle { text: "Cristal y color" }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    title: "Crimson Glass en el login"
                    desc: "Desenfoque real del navegador del login; no depende del compositor"
                    DToggle {
                        on: root.values.apariencia ? Boolean(root.values.apariencia.crimson_glass) : true
                        onToggled: function (value) {
                            root.guardar("apariencia", "crimson_glass", value)
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Intensidad del desenfoque"
                    desc: "Píxeles de desenfoque de los paneles"
                    Item {
                        width: 294
                        height: 40
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            DSlider {
                                width: 230
                                value: root.values.apariencia ? Number(root.values.apariencia.desenfoque_px) : 36
                                minimum: 0
                                maximum: 64
                                onMoved: function (value) {
                                    root.guardar("apariencia", "desenfoque_px", Math.round(value))
                                }
                            }
                            Text {
                                width: 50
                                text: (root.values.apariencia ? root.values.apariencia.desenfoque_px : 36) + " px"
                                color: Theme.c.textDim
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Color del login"
                    desc: "Sigue el color de acento de DylanOS Configuration o usa uno propio"
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        ActionButton {
                            text: "Usar color de acento"
                            onClicked: {
                                if (LoginManager.applyAccentColor()) {
                                    root.mensajeError = ""
                                    root.refrescar()
                                }
                            }
                        }
                        Rectangle {
                            width: 34
                            height: 34
                            radius: 10
                            color: root.effectiveValues.colorPrimario
                            border.width: 1
                            border.color: Theme.c.border
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Color personalizado"
                    desc: "Se aplica a los títulos, los controles activos y el botón de acceso"
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Repeater {
                            model: ["#dc143c", "#e8702a", "#1f9aa6", "#4caf50", "#7b4fe0", "#2f7be8"]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property string colorHex: modelData
                                width: 32
                                height: 32
                                radius: 10
                                color: colorHex
                                border.width: root.effectiveValues.colorPrimario === colorHex ? 2 : 1
                                border.color: root.effectiveValues.colorPrimario === colorHex
                                              ? Theme.c.text : Theme.c.border
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.guardar("apariencia", "color_primario", colorHex)
                                }
                            }
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Modo del login"
                    desc: "Claro u oscuro, independiente de la sesión"
                    DSelect {
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.values.apariencia && root.values.apariencia.modo === "light" ? "Claro" : "Oscuro"
                        options: ["Oscuro", "Claro"]
                        onPicked: function (value) {
                            root.guardar("apariencia", "modo", value === "Claro" ? "light" : "dark")
                        }
                    }
                }
            }
        }

        // --- Composición -------------------------------------------------
        Column {
            visible: root.tab === "Composición"
            width: parent.width
            spacing: 16

            SectionTitle { text: "Posición de los paneles" }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    title: "Distribución"
                    desc: "El prototipo usa columnas a los lados; centrada deja solo el reloj y el acceso"
                    DSegmented {
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.etiquetaPosicion(root.values.composicion
                                                     ? root.values.composicion.posicion_paneles : "clasica")
                        options: ["Clásica", "Centrada", "Izquierda"]
                        onPicked: function (value) {
                            root.guardar("composicion", "posicion_paneles", root.valorPosicion(value))
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Escala general"
                    desc: "Ajusta el tamaño de toda la interfaz del login"
                    Item {
                        width: 294
                        height: 40
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            DSlider {
                                width: 230
                                value: root.values.composicion ? Number(root.values.composicion.escala) : 1
                                minimum: 0.75
                                maximum: 1.25
                                onMoved: function (value) {
                                    root.guardar("composicion", "escala", Math.round(value * 100) / 100)
                                }
                            }
                            Text {
                                width: 50
                                text: Math.round((root.values.composicion ? root.values.composicion.escala : 1) * 100) + "%"
                                color: Theme.c.textDim
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Separación lateral"
                    desc: "Margen entre los paneles y el borde de la pantalla"
                    Item {
                        width: 294
                        height: 40
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            DSlider {
                                width: 230
                                value: root.values.composicion ? Number(root.values.composicion.margen_lateral) : 36
                                minimum: 8
                                maximum: 96
                                onMoved: function (value) {
                                    root.guardar("composicion", "margen_lateral", Math.round(value))
                                }
                            }
                            Text {
                                width: 50
                                text: (root.values.composicion ? root.values.composicion.margen_lateral : 36) + " px"
                                color: Theme.c.textDim
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            SectionTitle { text: "Tamaños" }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    title: "Tamaño del reloj"
                    desc: "El reloj es la pieza central de la pantalla"
                    Item {
                        width: 294
                        height: 40
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            DSlider {
                                width: 230
                                value: root.values.composicion ? Number(root.values.composicion.tamano_reloj) : 1
                                minimum: 0.6
                                maximum: 1.6
                                onMoved: function (value) {
                                    root.guardar("composicion", "tamano_reloj", Math.round(value * 100) / 100)
                                }
                            }
                            Text {
                                width: 50
                                text: Math.round((root.values.composicion ? root.values.composicion.tamano_reloj : 1) * 100) + "%"
                                color: Theme.c.textDim
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Tamaño del bloque de acceso"
                    desc: "Avatar, nombre y campo de contraseña"
                    Item {
                        width: 294
                        height: 40
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            DSlider {
                                width: 230
                                value: root.values.composicion ? Number(root.values.composicion.tamano_bloque_acceso) : 1
                                minimum: 0.7
                                maximum: 1.4
                                onMoved: function (value) {
                                    root.guardar("composicion", "tamano_bloque_acceso", Math.round(value * 100) / 100)
                                }
                            }
                            Text {
                                width: 50
                                text: Math.round((root.values.composicion ? root.values.composicion.tamano_bloque_acceso : 1) * 100) + "%"
                                color: Theme.c.textDim
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            SectionTitle { text: "Reloj" }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    title: "Formato de 24 horas"
                    DToggle {
                        on: root.values.reloj ? Boolean(root.values.reloj.formato_24_horas) : false
                        onToggled: function (value) {
                            root.guardar("reloj", "formato_24_horas", value)
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Mostrar la fecha"
                    DToggle {
                        on: root.values.reloj ? Boolean(root.values.reloj.mostrar_fecha) : true
                        onToggled: function (value) {
                            root.guardar("reloj", "mostrar_fecha", value)
                        }
                    }
                }
            }
        }


        // --- Datos de los widgets ----------------------------------------
        Column {
            visible: root.tab === "Datos"
            width: parent.width
            spacing: 16

            SectionTitle { text: "Clima" }
            Text {
                width: parent.width
                text: "El clima se consulta a open-meteo (servicio abierto, sin clave). "
                      + "Sin ubicación configurada el widget no se muestra."
                color: Theme.c.textDim
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    title: "Ubicación"
                    desc: "Latitud y longitud del lugar del que se muestra el clima"
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        TextField {
                            id: campoLatitud
                            width: 130
                            height: 34
                            placeholderText: "latitud"
                            text: root.values.clima && root.values.clima.latitud !== undefined
                                  && root.values.clima.latitud !== null
                                  ? String(root.values.clima.latitud) : ""
                            color: Theme.c.text
                            font.pixelSize: 13
                            background: Rectangle {
                                radius: Theme.radiusControl
                                color: Theme.c.field
                                border.width: 1
                                border.color: Theme.c.border
                            }
                        }
                        TextField {
                            id: campoLongitud
                            width: 130
                            height: 34
                            placeholderText: "longitud"
                            text: root.values.clima && root.values.clima.longitud !== undefined
                                  && root.values.clima.longitud !== null
                                  ? String(root.values.clima.longitud) : ""
                            color: Theme.c.text
                            font.pixelSize: 13
                            background: Rectangle {
                                radius: Theme.radiusControl
                                color: Theme.c.field
                                border.width: 1
                                border.color: Theme.c.border
                            }
                        }
                        ActionButton {
                            text: "Guardar ubicación"
                            onClicked: {
                                var lat = parseFloat(campoLatitud.text.replace(",", "."))
                                var lon = parseFloat(campoLongitud.text.replace(",", "."))
                                if (isNaN(lat) || isNaN(lon) || lat < -90 || lat > 90
                                        || lon < -180 || lon > 180) {
                                    root.mensajeError = "La latitud debe estar entre -90 y 90 y la longitud entre -180 y 180."
                                    return
                                }
                                var clima = root.values.clima ? root.values.clima : {}
                                clima.latitud = lat
                                clima.longitud = lon
                                clima.proveedor = "open-meteo"
                                LoginManager.setOption("clima", "latitud", lat)
                                LoginManager.setOption("clima", "longitud", lon)
                                LoginManager.setOption("clima", "proveedor", "open-meteo")
                                root.mensajeError = ""
                                root.refrescar()
                            }
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Nombre del lugar"
                    desc: "Opcional: solo se usa para tu referencia"
                    TextField {
                        width: 240
                        height: 34
                        placeholderText: "p. ej. Bogotá"
                        text: root.values.clima && root.values.clima.lugar ? root.values.clima.lugar : ""
                        color: Theme.c.text
                        font.pixelSize: 13
                        background: Rectangle {
                            radius: Theme.radiusControl
                            color: Theme.c.field
                            border.width: 1
                            border.color: Theme.c.border
                        }
                        onEditingFinished: {
                            LoginManager.setOption("clima", "lugar", text)
                            root.refrescar()
                        }
                    }
                }
            }

            SectionTitle { text: "Próximo evento" }
            Text {
                width: parent.width
                text: "El login no tiene calendario de sistema: el evento se lee de un fichero "
                      + ".ics local. Sin fichero, el widget no se muestra."
                color: Theme.c.textDim
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    title: "Fichero de calendario (.ics)"
                    desc: "Ruta completa al calendario que quieres mostrar"
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        TextField {
                            width: 300
                            height: 34
                            placeholderText: "/home/usuario/Calendars/personal.ics"
                            text: root.values.calendario && root.values.calendario.ics
                                  ? root.values.calendario.ics : ""
                            color: Theme.c.text
                            font.pixelSize: 13
                            background: Rectangle {
                                radius: Theme.radiusControl
                                color: Theme.c.field
                                border.width: 1
                                border.color: Theme.c.border
                            }
                            onEditingFinished: {
                                LoginManager.setOption("calendario", "ics", text)
                                root.refrescar()
                            }
                        }
                        ActionButton {
                            text: "Quitar"
                            onClicked: {
                                LoginManager.setOption("calendario", "ics", "")
                                root.refrescar()
                            }
                        }
                    }
                }
            }

            SectionTitle { text: "Recordatorios" }
            Text {
                width: parent.width
                text: "Hasta cuatro, como en el prototipo. Se guardan con la configuración del login."
                color: Theme.c.textDim
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    title: "Nuevo recordatorio"
                    desc: "Se añade al final de la lista"
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        TextField {
                            id: campoRecordatorio
                            width: 300
                            height: 34
                            placeholderText: "Escribe un recordatorio"
                            color: Theme.c.text
                            font.pixelSize: 13
                            background: Rectangle {
                                radius: Theme.radiusControl
                                color: Theme.c.field
                                border.width: 1
                                border.color: Theme.c.border
                            }
                        }
                        ActionButton {
                            text: "Añadir"
                            onClicked: {
                                var texto = campoRecordatorio.text.trim()
                                if (texto === "") return
                                var lista = root.listaRecordatorios()
                                if (lista.length >= 4) {
                                    root.mensajeError = "El login admite 4 recordatorios como máximo."
                                    return
                                }
                                lista.push({ texto: texto, hecho: false })
                                root.guardarRecordatorios(lista)
                                campoRecordatorio.text = ""
                            }
                        }
                    }
                }
                Repeater {
                    model: root.listaRecordatorios()
                    delegate: RowItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        title: modelData.texto
                        last: index === root.listaRecordatorios().length - 1
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            BadgePill {
                                text: modelData.hecho ? "Hecho" : "Pendiente"
                                tone: modelData.hecho ? "#58D68D" : "#B3B3B3"
                            }
                            ActionButton {
                                text: "Quitar"
                                variant: "danger"
                                onClicked: {
                                    var lista = root.listaRecordatorios()
                                    lista.splice(index, 1)
                                    root.guardarRecordatorios(lista)
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Atajos ------------------------------------------------------
        Column {
            visible: root.tab === "Atajos"
            width: parent.width
            spacing: 16

            SectionTitle { text: "Atajos del login (" + root.seleccionAtajos.length + " / 4)" }
            Text {
                width: parent.width
                text: "El login dibuja los atajos en una rejilla de dos columnas con cuatro huecos, igual que el prototipo. "
                      + "Cada atajo ejecuta una acción real del sistema."
                color: Theme.c.textDim
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            GroupBox {
                width: parent.width
                Repeater {
                    model: root.atajosCatalogo
                    delegate: RowItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        title: modelData.nombre
                        desc: modelData.descripcion
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            BadgePill {
                                text: modelData.fuente
                                tone: "#B3B3B3"
                            }
                            DToggle {
                                on: root.estaActivo(modelData.id)
                                onToggled: root.alternarAtajo(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // --- Widgets -----------------------------------------------------
        Column {
            visible: root.tab === "Widgets"
            width: parent.width
            spacing: 16

            SectionTitle { text: "Widgets del login" }
            Text {
                width: parent.width
                text: "Cada widget declara de dónde salen sus datos. Si el sistema no puede ofrecerlos, "
                      + "el login lo oculta en lugar de mostrar cifras inventadas."
                color: Theme.c.textDim
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            GroupBox {
                width: parent.width
                Repeater {
                    model: root.widgetsCatalogo
                    delegate: RowItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        title: modelData.nombre
                        desc: modelData.nota
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            BadgePill {
                                text: modelData.columna === "izquierda" ? "Izquierda" : "Derecha"
                                tone: "#2f7be8"
                            }
                            BadgePill {
                                text: modelData.fuente
                                tone: "#B3B3B3"
                            }
                        }
                    }
                }
            }
        }

        // --- Vista previa real -------------------------------------------
        Column {
            visible: root.tab === "Vista previa"
            width: parent.width
            spacing: 16

            SectionTitle { text: "Vista previa del login" }
            Text {
                width: parent.width
                text: "Es una captura del propio login con la configuración guardada: lo que ves aquí es exactamente lo que aparecerá al bloquear o reiniciar."
                color: Theme.c.textDim
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            Row {
                spacing: 12
                ActionButton {
                    text: root.generandoVista ? "Generando…" : "Actualizar vista previa"
                    enabled2: !root.generandoVista && LoginManager.available
                    onClicked: root.actualizarVista()
                }
                ActionButton {
                    text: "Restablecer el login"
                    onClicked: {
                        if (LoginManager.reset()) {
                            root.mensajeError = ""
                            root.refrescar()
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: width * 0.6667
                radius: 18
                color: "#07070a"
                border.width: 1
                border.color: Theme.c.border
                clip: true
                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: LoginManager.previewUrl
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: LoginManager.previewUrl.length > 0
                }
                Text {
                    anchors.centerIn: parent
                    visible: LoginManager.previewUrl.length === 0
                    text: "Pulsa «Actualizar vista previa» para ver el login real"
                    color: Theme.c.textDim
                    font.pixelSize: 13
                }
            }
        }
    }
}
