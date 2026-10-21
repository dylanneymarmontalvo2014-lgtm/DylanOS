import QtQuick
import org.dylanos.configuration

// Icono Lucide renderizado por el proveedor "image://lucide" con color dinámico.
Image {
    property string name
    property color color: Theme.c.text
    property int size: 24

    width: size
    height: size
    source: name ? "image://lucide/" + name + "/" + color.toString().slice(-6) : ""
    sourceSize: Qt.size(size * Screen.devicePixelRatio, size * Screen.devicePixelRatio)
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
}
