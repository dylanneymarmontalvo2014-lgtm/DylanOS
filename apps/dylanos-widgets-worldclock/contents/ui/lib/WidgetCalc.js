.pragma library

/*
 * Evaluador aritmético acotado de DylanOS Widgets.
 *
 * No usa `eval` ni `Function`: un evaluador sin límites permitía bloquear la
 * interfaz con expresiones como 9**99999999, que es justo el fallo que se
 * corrigió en Spotlight. Aquí solo existen números, + - * / % y paréntesis;
 * cualquier otro carácter invalida la expresión.
 *
 * Está separado de la vista para poder ejecutarlo con `node`
 * (scripts/tests/test_widgets.py) y comprobar el comportamiento real.
 */

var MAX_LENGTH = 48;
var MAX_MAGNITUDE = 1e15;

/*
 * Devuelve { ok: true, value } o { ok: false }.
 * Un delta inválido nunca produce un número: el widget muestra el error.
 */
function evaluate(input) {
    var text = String(input === undefined || input === null ? "" : input)
        .replace(/,/g, ".").trim();
    if (text.length === 0 || text.length > MAX_LENGTH)
        return { ok: false };

    var pos = 0;

    function skipSpaces() {
        while (pos < text.length && text.charAt(pos) === " ")
            pos += 1;
    }

    function parseExpr() {
        var value = parseTerm();
        if (value === null)
            return null;
        skipSpaces();
        while (pos < text.length) {
            var op = text.charAt(pos);
            if (op !== "+" && op !== "-")
                break;
            pos += 1;
            var right = parseTerm();
            if (right === null)
                return null;
            value = op === "+" ? value + right : value - right;
            skipSpaces();
        }
        return value;
    }

    function parseTerm() {
        var value = parseFactor();
        if (value === null)
            return null;
        skipSpaces();
        while (pos < text.length) {
            var op = text.charAt(pos);
            if (op !== "*" && op !== "/" && op !== "%")
                break;
            pos += 1;
            var right = parseFactor();
            if (right === null)
                return null;
            if (op === "*") {
                value = value * right;
            } else if (op === "/") {
                if (right === 0)
                    return null;
                value = value / right;
            } else {
                if (right === 0)
                    return null;
                value = value % right;
            }
            skipSpaces();
        }
        return value;
    }

    function parseFactor() {
        skipSpaces();
        if (pos >= text.length)
            return null;
        var ch = text.charAt(pos);
        if (ch === "-") {
            pos += 1;
            var inner = parseFactor();
            return inner === null ? null : -inner;
        }
        if (ch === "(") {
            pos += 1;
            var nested = parseExpr();
            skipSpaces();
            if (nested === null || text.charAt(pos) !== ")")
                return null;
            pos += 1;
            return nested;
        }
        var match = text.slice(pos).match(/^\d+(?:\.\d+)?/);
        if (!match)
            return null;
        pos += match[0].length;
        var value = Number(match[0]);
        return isFinite(value) ? value : null;
    }

    var result = parseExpr();
    skipSpaces();
    if (result === null || pos !== text.length || !isFinite(result))
        return { ok: false };
    if (Math.abs(result) > MAX_MAGNITUDE)
        return { ok: false };
    return { ok: true, value: result };
}

/* Presentación del resultado: sin .0 espurios ni ruido de coma flotante. */
function formatValue(value) {
    if (!isFinite(value))
        return "";
    if (Math.abs(value - Math.round(value)) < 1e-9)
        return String(Math.round(value));
    return String(parseFloat(value.toFixed(6)));
}
