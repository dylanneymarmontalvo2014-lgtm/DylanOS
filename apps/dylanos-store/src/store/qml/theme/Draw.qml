pragma Singleton
import QtQuick

QtObject {
    // SVG path of a rounded rectangle, used by Shape-based gradients.
    function roundRect(x, y, w, h, r) {
        r = Math.max(0, Math.min(r, w / 2, h / 2))
        return "M " + (x + r) + " " + y + " H " + (x + w - r) + " A " + r + " " + r + " 0 0 1 " + (x + w) + " " + (y + r)
            + " V " + (y + h - r) + " A " + r + " " + r + " 0 0 1 " + (x + w - r) + " " + (y + h)
            + " H " + (x + r) + " A " + r + " " + r + " 0 0 1 " + x + " " + (y + h - r)
            + " V " + (y + r) + " A " + r + " " + r + " 0 0 1 " + (x + r) + " " + y + " Z"
    }
}
