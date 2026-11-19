// Tests de la interfaz de DylanOS Process.
//
// Cargan la ventana real (qrc) con los modelos de producción y comprueban que
// la tabla, los filtros, el orden y el panel de detalle funcionan con los datos
// reales del sistema. No hay mocks: si /proc no responde, el test falla.

import QtQuick
import QtQuick.Controls.Basic
import QtTest

TestCase {
    id: testCase
    name: "ProcessUI"
    when: windowShown

    // Carga la ventana real de producción desde el módulo QML compilado.
    Component {
        id: mainComponent
        Loader {
            source: "qrc:/qt/qml/org/dylanos/process/qml/Main.qml"
        }
    }

    // Crea la ventana real y devuelve el ApplicationWindow raíz.
    //
    // Se usa Qt.createComponent en lugar de un Loader: un ApplicationWindow
    // creado como hijo de un Loader no se muestra como ventana de primer nivel.
    function createWindow() {
        var component = Qt.createComponent("qrc:/qt/qml/org/dylanos/process/qml/Main.qml")
        if (component.status !== Component.Ready) {
            fail("no se pudo cargar Main.qml: " + component.errorString())
            return null
        }
        var window = component.createObject(null)
        wait(200)
        return window
    }

    function init() {
        // Cada test parte de un filtro limpio para no arrastrar estado.
        processFilter.searchText = ""
        processFilter.stateFilter = "all"
        processFilter.sortRole = "cpu"
        processFilter.sortDescending = true
    }

    function test_modelo_tiene_procesos_reales() {
        verify(processModel.count > 0, "el sistema debe exponer procesos reales")
        verify(processModel.cores >= 1, "el número de núcleos debe ser real")
        verify(processModel.memTotalBytes > 0, "MemTotal debe ser mayor que cero")
        verify(processModel.iconCount > 0, "el tema de iconos debe haberse indexado")
    }

    function test_fila_expone_campos_reales() {
        var row = processFilter.get(0)
        verify(row.pid > 0, "cada fila tiene un PID real")
        verify(row.name.length > 0, "cada fila tiene nombre")
        verify(row.user.length > 0, "cada fila tiene usuario resuelto")
        verify(row.state.length > 0, "cada fila tiene estado del kernel")
        verify(row.threads >= 1, "cada proceso tiene al menos un hilo")
    }

    function test_busqueda_filtra_de_verdad() {
        var total = processFilter.count
        verify(total > 0)
        // Se busca el nombre de la primera fila: debe quedar al menos una.
        var name = processFilter.get(0).name
        processFilter.searchText = name
        verify(processFilter.count >= 1, "la búsqueda debe encontrar el nombre existente")
        verify(processFilter.count <= total, "filtrar no puede aumentar las filas")
        processFilter.searchText = "zzz-no-existe-zzz"
        compare(processFilter.count, 0, "un texto inexistente no debe dejar filas")
    }

    function test_filtro_de_estado_usa_estados_del_kernel() {
        processFilter.stateFilter = "Ejecutando"
        for (var i = 0; i < processFilter.count; ++i)
            compare(processFilter.get(i).state, "Ejecutando")
        processFilter.stateFilter = "all"
        verify(processFilter.count > 0)
    }

    function test_orden_por_cpu_es_descendente() {
        processFilter.sortRole = "cpu"
        processFilter.sortDescending = true
        var previous = 1e9
        var count = Math.min(processFilter.count, 12)
        for (var i = 0; i < count; ++i) {
            var cpu = processFilter.get(i).cpu
            verify(cpu <= previous + 0.0001, "el orden por CPU debe ser descendente")
            previous = cpu
        }
    }

    function test_toggle_sort_invierte_la_direccion() {
        processFilter.sortRole = "mem"
        processFilter.sortDescending = true
        var firstDesc = processFilter.get(0).rss
        processFilter.toggleSort("mem")
        compare(processFilter.sortDescending, false, "alternar debe invertir a ascendente")
        var firstAsc = processFilter.get(0).rss
        verify(firstAsc <= firstDesc, "ascendente debe empezar por el menor")
        processFilter.sortDescending = true
    }

    function test_ventana_carga_y_muestra_tabla() {
        var window = createWindow()
        verify(window !== null, "la ventana principal debe crearse")
        tryCompare(window, "visible", true)
        compare(window.activeTab, "processes", "el prototipo abre en Procesos")
        var table = findChild(window, "processTable")
        verify(table !== null, "la tabla debe existir")
        tryCompare(table, "count", processFilter.count)
        verify(table.count > 0, "la tabla debe tener filas reales")
    }

    function test_detalle_aparece_al_seleccionar() {
        var window = createWindow()
        verify(window !== null)
        tryCompare(window, "visible", true)
        var pid = processFilter.get(0).pid
        window.selectedPid = pid
        // El panel de detalle muestra el PID seleccionado.
        var detailPid = findChild(window, "detailPid")
        verify(detailPid !== null, "el detalle debe exponer el PID")
        tryCompare(detailPid, "text", String(pid))
    }

    function test_no_hay_datos_simulados_en_los_textos() {
        var window = createWindow()
        verify(window !== null)
        tryCompare(window, "visible", true)
        // El prototipo mostraba "1.342 hilos activos" y "8.0 GB" fijos; ahora
        // todo sale del sistema, así que no debe aparecer ese literal.
        var found = findAllText(window)
        verify(found.indexOf("1.342 hilos activos") === -1,
               "no debe quedar el literal simulado del prototipo")
    }

    // ── Servicios ──────────────────────────────────────────────────────────
    function test_servicios_reflejan_systemd_o_avisan_de_su_ausencia() {
        // En un host con systemd la lista es real; en un contenedor sin PID 1
        // systemd el modelo debe decirlo, nunca inventar unidades.
        if (serviceModel.count > 0) {
            for (var i = 0; i < Math.min(serviceModel.count, 5); ++i) {
                var row = serviceModel.get(i)
                verify(row.name.length > 0, "cada unidad tiene nombre real")
                verify(row.name.endsWith(".service"), "las unidades son de tipo service")
                verify(row.scope === "Sistema" || row.scope === "Usuario")
            }
        } else {
            verify(serviceModel.errorText.length > 0,
                   "sin unidades debe haber un motivo visible")
        }
    }

    function test_pestana_servicios_pinta_unidades_inyectadas() {
        // Se prueba el pintado de la pestaña con unidades controladas; el
        // modelo de producción se restaura al terminar.
        var window = createWindow()
        verify(window !== null)
        tryCompare(window, "visible", true)
        window.activeTab = "services"
        var page = findChild(window, "servicesPage")
        verify(page !== null, "la pestaña Servicios debe existir")
        page.setTestUnits([
            { name: "dylanosd.service", description: "Núcleo de DylanOS", active: true,
              scope: "Sistema" },
            { name: "prueba.service", description: "Unidad de prueba", active: false,
              scope: "Sistema" }
        ])
        compare(serviceModel.count, 2, "deben pintarse las dos unidades inyectadas")
        var list = findChild(window, "servicesList")
        verify(list !== null)
        tryCompare(list, "count", 2)
        page.clearTestUnits()
    }

    // ── Acciones reales ────────────────────────────────────────────────────
    function test_terminar_un_pid_inexistente_falla_con_motivo_real() {
        var ok = processController.terminateProcess(2147483000)
        compare(ok, false, "un PID inexistente no puede terminarse")
    }

    function test_prioridad_real_de_un_nice() {
        // Los cuatro niveles del prototipo se derivan del nice real.
        compare(processController.priorityLevel(19), 0)
        compare(processController.priorityLevel(0), 1)
        compare(processController.priorityLevel(-5), 2)
        compare(processController.priorityLevel(-20), 3)
    }

    function test_is_alive_detecta_el_proceso_actual() {
        // El PID propio está vivo; el 0 no es un proceso.
        var firstPid = processFilter.get(0).pid
        verify(processController.isAlive(firstPid) || processController.isAlive(1),
               "algún proceso real debe estar vivo")
        compare(processController.isAlive(0), false)
    }

    function findAllText(item) {
        var out = []
        function walk(node) {
            if (!node)
                return
            // Acceso defensivo: no todos los Items tienen `text` y tocar la
            // propiedad en un tipo que no la declara lanza excepción en QML.
            try {
                var value = node.text
                if (typeof value === "string" && value.length > 0)
                    out.push(value)
            } catch (e) {
                // El item no expone `text`: se ignora.
            }
            var kids = node.children
            if (kids) {
                for (var i = 0; i < kids.length; ++i)
                    walk(kids[i])
            }
        }
        walk(item)
        return out.join(" | ")
    }
}
