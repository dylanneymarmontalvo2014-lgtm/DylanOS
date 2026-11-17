.pragma library

/*
 * DylanOS Widgets — tokens visuales compartidos.
 *
 * Biblioteca JS (`.pragma library`), no singleton QML: un plasmoid se carga
 * desde el sistema de archivos (*no* desde qrc) y los singletons exigen una
 * declaración en qmldir y un import path real. Este es el mismo patrón que
 * ya usa apps/com.dylanos.dashboard con PomodoroClock.js, así que no añade
 * ningún mecanismo nuevo.
 *
 * Ningún widget debe declarar un color literal: la auditoría
 * docs/auditoria-diseno-tahoe-crimson.md documentó la deriva cromática que
 * provoca tener valores sueltos (#e11d2e, #ff4d5a…) en lugar de los
 * oficiales de branding/colors/dylanos.conf.
 *
 * Ojo con el orden de los canales: Qt interpreta un color de 8 dígitos como
 * #AARRGGBB, no como el #RRGGBBAA de CSS.
 */

// ── Marca (branding/colors/dylanos.conf) ────────────────────────────────
var crimson = "#DC143C";
var crimsonHover = "#FF4565";
var crimsonPressed = "#A50F2E";
var black = "#0A0A0A";
var gray = "#1A1A1A";
var white = "#FFFFFF";
var lightGray = "#B3B3B3";

// Gradientes oficiales de la UI.
var gradientTop = "#E81740";
var gradientBottom = "#AD0A2A";
var gradientHoverTop = "#FF2A54";
var gradientHoverBottom = "#C90E33";

// ── Material Crimson Glass ──────────────────────────────────────────────
var variantDark = "dark";
var variantCrimson = "crimson";
var variantLight = "light";

var materialOpacity = 0.55;
var materialOpacityPerformance = 0.92;

var materialFill = {
    "dark": "#8C0A0A0A",
    "crimson": "#8C2A0A12",
    "light": "#B3F2F2F2"
};

// Tono superior del vidrio: la luz entra por arriba, así que la tarjeta se
// aclara en la primera banda. Un relleno plano se lee como un hueco negro.
var materialFillTop = {
    "dark": "#B3202024",
    "crimson": "#B33C1420",
    "light": "#CCC9C9CC"
};

var materialText = {
    "dark": "#FFFFFF",
    "crimson": "#FFFFFF",
    "light": "#0A0A0A"
};

var materialTextSecondary = {
    "dark": "#B3B3B3",
    "crimson": "#D8C8CE",
    "light": "#4A4A4A"
};

// ── Geometría ───────────────────────────────────────────────────────────
var radiusWidget = 22;
var radiusInner = 14;
var radiusControl = 10;

// Retícula de 4 puntos: todo el espaciado interior es múltiplo.
var space1 = 4;
var space2 = 8;
var space3 = 12;
var space4 = 16;
var space5 = 20;
var space6 = 24;

// ── Tipografía ──────────────────────────────────────────────────────────
// Inter es la fuente oficial del escritorio (defaults del look-and-feel).
var fontFamily = "Inter";
var fontSizeDisplay = 42;
var fontSizeTitle = 20;
var fontSizeHeading = 15;
var fontSizeBody = 13;
var fontSizeCaption = 11;

// ── Movimiento ──────────────────────────────────────────────────────────
var durationFast = 120;
var durationNormal = 180;

// ── Contrato de tamaños ─────────────────────────────────────────────────
// Espejo exacto de SIZE_CELLS en scripts/dylanos-widget-layout; el test de
// contrato comprueba que no divergen.
var small = "small";
var mediumWide = "medium-wide";
var mediumTall = "medium-tall";
var large = "large";
var extraLarge = "extra-large";

var cells = {
    "small": { "w": 1, "h": 1 },
    "medium-wide": { "w": 2, "h": 1 },
    "medium-tall": { "w": 1, "h": 2 },
    "large": { "w": 2, "h": 2 },
    "extra-large": { "w": 4, "h": 2 }
};

var minCell = 120;
var maxCell = 190;
var defaultCell = 140;

/*
 * Lado de celda a partir del alto de la pantalla: seis celdas de alto dejan
 * sitio a la fila de arriba, a la de abajo y al dock sin cubrir el
 * escritorio. Acotado para no degradarse en pantallas extremas.
 */
function cellFor(screenHeight) {
    var raw = Math.round((screenHeight || 0) / 6);
    if (!isFinite(raw) || raw <= 0)
        return defaultCell;
    return Math.max(minCell, Math.min(maxCell, raw));
}

function marginFor(cellSize) {
    return Math.round((cellSize || defaultCell) / 3);
}

function widthFor(sizeClass, cellSize) {
    var spec = cells[sizeClass] || cells[small];
    return spec.w * cellSize;
}

function heightFor(sizeClass, cellSize) {
    var spec = cells[sizeClass] || cells[small];
    return spec.h * cellSize;
}

function supports(sizeClass, supported) {
    return Array.isArray(supported) && supported.indexOf(sizeClass) !== -1;
}
