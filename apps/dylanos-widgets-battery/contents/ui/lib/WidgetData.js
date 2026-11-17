.pragma library

/*
 * DylanOS Widgets — lectura y formateo de datos del sistema.
 *
 * Estas funciones son puras a propósito: reciben el texto crudo de /proc, df o
 * un archivo y devuelven números. Así se pueden ejecutar y verificar con
 * `node` (scripts/tests/test_widgets.py), en lugar de comprobar solo que el
 * QML parsea.
 *
 * Las fórmulas replican las que ya usa DylanOS Configuration en
 * SystemService::sysInfo() —CPU con cadena de fuentes y RAM ajustada a la
 * potencia de dos más próxima— para que el mismo equipo no muestre cifras
 * distintas en el widget y en la app de configuración.
 */

/* ── CPU ────────────────────────────────────────────────────────────────
 * /proc/stat, primera línea. Los contadores guest y guest_nice ya están
 * incluidos en user y nice: sumarlos otra vez inflaba el total (fallo real
 * corregido en el dashboard el 2026-10-24).
 */
function cpuCountersFromStatLine(line) {
    var parts = String(line || "").trim().split(/\s+/);
    if (parts.length < 8 || parts[0] !== "cpu")
        return null;
    var user = Number(parts[1]);
    var nice = Number(parts[2]);
    var system = Number(parts[3]);
    var idle = Number(parts[4]);
    var iowait = Number(parts[5]) || 0;
    var irq = Number(parts[6]) || 0;
    var softirq = Number(parts[7]) || 0;
    var steal = Number(parts[8]) || 0;
    var nums = [user, nice, system, idle, iowait, irq, softirq, steal];
    for (var i = 0; i < nums.length; ++i) {
        if (!isFinite(nums[i]) || nums[i] < 0)
            return null;
    }
    return {
        total: user + nice + system + idle + iowait + irq + softirq + steal,
        idle: idle + iowait
    };
}

/*
 * Uso de CPU entre dos muestras. Devuelve null si el delta es incoherente
 * (contadores que retroceden, idle mayor que total) en lugar de mostrar un
 * porcentaje inválido.
 */
function cpuUsagePercent(previousTotal, previousIdle, currentTotal, currentIdle) {
    if (!isFinite(previousTotal) || !isFinite(previousIdle)
        || !isFinite(currentTotal) || !isFinite(currentIdle))
        return null;
    if (previousTotal < 0 || previousIdle < 0)
        return null;
    var totalDelta = currentTotal - previousTotal;
    var idleDelta = currentIdle - previousIdle;
    if (totalDelta <= 0 || idleDelta < 0 || idleDelta > totalDelta)
        return null;
    return Math.max(0, Math.min(100, 100 * (1 - idleDelta / totalDelta)));
}

/* ── Memoria ──────────────────────────────────────────────────────────── */
function parseMemInfo(text) {
    var total = String(text || "").match(/MemTotal:\s+(\d+)/);
    var available = String(text || "").match(/MemAvailable:\s+(\d+)/);
    if (!total)
        return null;
    var totalKb = Number(total[1]);
    if (!isFinite(totalKb) || totalKb <= 0)
        return null;
    var availableKb = available ? Number(available[1]) : 0;
    return {
        totalKb: totalKb,
        usedKb: Math.max(0, totalKb - availableKb)
    };
}

/*
 * La RAM se redondea a la potencia de dos más próxima cuando la diferencia es
 * ≤10 %: MemTotal recorta lo que reserva el firmware, así que un equipo de
 * 8 GB declara 7,6 GiB. Sin esto el widget mostraría "7.60 GB".
 */
function roundMemoryGb(totalKb) {
    var gb = totalKb / 1024 / 1024;
    if (!isFinite(gb) || gb <= 0)
        return 0;
    var lower = Math.pow(2, Math.floor(Math.log(gb) / Math.LN2));
    var upper = lower * 2;
    var nearest = Math.abs(gb - lower) <= Math.abs(gb - upper) ? lower : upper;
    if (gb > 0 && Math.abs(nearest - gb) / gb <= 0.10)
        return Math.round(nearest);
    return Math.round(gb);
}

/* ── Almacenamiento ───────────────────────────────────────────────────── */
function parseDfOutput(text) {
    var match = String(text || "").match(/^\s*(\d+)\s+(\d+)\s*$/m);
    if (!match)
        return null;
    var used = Number(match[1]);
    var total = Number(match[2]);
    if (!isFinite(total) || total <= 0)
        return null;
    return { usedBytes: used, totalBytes: total };
}

/* ── Batería ──────────────────────────────────────────────────────────── */
function parseUpowerPercentage(value) {
    var v = Number(value);
    if (!isFinite(v) || v < 0)
        return null;
    // UPower 1.x ya publica 0–100; versiones antiguas publicaban 0–1.
    if (v <= 1)
        return Math.round(v * 100);
    return Math.round(v);
}

/* ── Actualizaciones ──────────────────────────────────────────────────── */
/*
 * Cuenta líneas "Inst pak" de `apt-get -s upgrade` (simulación, no instala).
 * Debian 13 sale de la simulación sin tocar el sistema de archivos.
 */
function countAptUpgrades(text) {
    var lines = String(text || "").split("\n");
    var count = 0;
    for (var i = 0; i < lines.length; ++i) {
        if (/^Inst\s+\S+/.test(lines[i]))
            count += 1;
    }
    return count;
}

/* ── Formateo ─────────────────────────────────────────────────────────── */
function formatBytes(bytes) {
    var value = Number(bytes);
    if (!isFinite(value) || value < 0)
        return "—";
    var units = ["B", "KB", "MB", "GB", "TB"];
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
        value /= 1024;
        index += 1;
    }
    // Una decimal solo cuando aporta: 1,5 GB sí, 512 MB no.
    var decimals = (index >= 3 && value < 100) ? 1 : 0;
    return value.toFixed(decimals).replace(".", ",") + " " + units[index];
}

function formatPercent(value) {
    var v = Number(value);
    if (!isFinite(v) || v < 0)
        return "—";
    return Math.round(v) + " %";
}

/* ── Próximo evento (.ics) ────────────────────────────────────────────── */
/*
 * Extrae el próximo evento futuro de un calendario iCalendar. Devuelve null
 * si no hay ninguno: el widget muestra un estado explícito, nunca un evento
 * inventado.
 *
 * Soporta DTSTART en formato UTC (YYYYMMDDTHHMMSSZ) y local
 * (YYYYMMDDTHHMMSS), que es lo que escriben Google Calendar, Nextcloud y
 * Thunderbird. Ignora eventos de día completo (VALUE=DATE) porque no tienen
 * hora de inicio.
 */
function parseNextEvent(icsText, nowMs) {
    var text = String(icsText || "");
    if (text.indexOf("BEGIN:VCALENDAR") === -1)
        return null;
    var now = isFinite(nowMs) ? nowMs : 0;
    var blocks = text.split("BEGIN:VEVENT");
    var best = null;
    for (var i = 1; i < blocks.length; ++i) {
        var block = blocks[i].split("END:VEVENT")[0];
        var summary = block.match(/SUMMARY:(.*)/);
        var start = block.match(/DTSTART[^:\n]*:(\d{8}T\d{6}Z?)/);
        if (!start)
            continue;
        var raw = start[1];
        var year = Number(raw.substr(0, 4));
        var month = Number(raw.substr(4, 2)) - 1;
        var day = Number(raw.substr(6, 2));
        var hour = Number(raw.substr(9, 2));
        var minute = Number(raw.substr(11, 2));
        var second = Number(raw.substr(13, 2));
        var utc = raw.charAt(raw.length - 1) === "Z";
        var startMs = utc
            ? Date.UTC(year, month, day, hour, minute, second)
            : new Date(year, month, day, hour, minute, second).getTime();
        if (!isFinite(startMs) || startMs < now)
            continue;
        if (best === null || startMs < best.startMs) {
            best = {
                startMs: startMs,
                title: summary ? decodeIcsText(summary[1]).trim() : "",
                allDay: false
            };
        }
    }
    return best;
}

/* Deshace el escapado de texto de iCalendar (\\, \\, y \\n). */
function decodeIcsText(value) {
    return String(value || "")
        .replace(/\\n/gi, " ")
        .replace(/\\,/g, ",")
        .replace(/\\;/g, ";")
        .replace(/\\\\/g, "\\");
}

/* ── Zonas horarias ───────────────────────────────────────────────────── */
/*
 * El motor JS de QML NO incluye Intl (verificado: `typeof Intl` es
 * "undefined"), así que `toLocaleTimeString` con timeZone no existe en un
 * plasmoid. La alternativa es TZInfo, que Qt expone en QML y lee la base de
 * zonas del sistema.
 *
 * Estas funciones se conservan solo para los tests con `node`; el widget usa
 * TZInfo.createTimeZone directamente.
 */
function timezoneOffsetMinutes(zone, dateMs) {
    try {
        var date = new Date(dateMs);
        var local = new Date(date.toLocaleString("en-US", { timeZone: zone }));
        var utc = new Date(date.toLocaleString("en-US", { timeZone: "UTC" }));
        return Math.round((local.getTime() - utc.getTime()) / 60000);
    } catch (error) {
        return null;
    }
}

function formatInZone(zone, dateMs, use24h) {
    // Solo válido fuera del motor QML (p. ej. en los tests con node), donde
    // Intl sí existe. En un plasmoid se usa TZInfo.
    if (typeof Intl === "undefined")
        return null;
    try {
        return new Date(dateMs).toLocaleTimeString("es-ES", {
            timeZone: zone,
            hour: "2-digit",
            minute: "2-digit",
            hour12: use24h === false
        });
    } catch (error) {
        return null;
    }
}
