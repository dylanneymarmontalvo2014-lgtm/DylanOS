// Formato numérico compartido por toda la interfaz.
//
// Un único lugar para las conversiones evita que cada página invente su propio
// redondeo: las cifras de la misma magnitud se ven igual en tarjetas, tabla y
// detalle. Todos los valores provienen del núcleo, ya en unidades del SI.
pragma Singleton
import QtQuick

QtObject {
    function bytes(value) {
        var v = Number(value)
        if (v < 1024)
            return v.toFixed(0) + " B"
        if (v < 1048576)
            return (v / 1024).toFixed(1) + " KB"
        if (v < 1073741824)
            return (v / 1048576).toFixed(1) + " MB"
        return (v / 1073741824).toFixed(1) + " GB"
    }

    /// Memoria con la forma del prototipo: GB a partir de 1 GB, si no MB.
    function memory(value) {
        var gb = Number(value) / 1073741824
        return gb >= 1 ? gb.toFixed(1) + " GB" : (Number(value) / 1048576).toFixed(0) + " MB"
    }

    /// Valor sin unidad (las tarjetas pintan la unidad aparte).
    function memoryValue(value) {
        var gb = Number(value) / 1073741824
        return gb >= 1 ? gb.toFixed(1) : (Number(value) / 1048576).toFixed(0)
    }

    function rate(bytesPerSecond) {
        var v = Number(bytesPerSecond)
        if (v < 1024)
            return v.toFixed(0) + " B/s"
        if (v < 1048576)
            return (v / 1024).toFixed(1) + " KB/s"
        return (v / 1048576).toFixed(1) + " MB/s"
    }

    function percent(value) {
        return Number(value).toFixed(1) + " %"
    }

    function duration(seconds) {
        var s = Number(seconds)
        if (s < 60)
            return s.toFixed(0) + " s"
        var m = Math.floor(s / 60)
        if (m < 60)
            return m + " min"
        var h = Math.floor(m / 60)
        if (h < 24)
            return h + " h " + (m % 60) + " min"
        return Math.floor(h / 24) + " d " + (h % 24) + " h"
    }

    /// Ratio 0..1 seguro para barras y gráficas.
    function ratio(value, total) {
        var t = Number(total)
        if (!t || t <= 0)
            return 0
        return Math.max(0, Math.min(1, Number(value) / t))
    }
}
