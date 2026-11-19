// Icono real del proceso según el tema de iconos del sistema.
//
// Si el tema no tiene icono, se muestra la inicial sobre un fondo neutro: es el
// último recurso, nunca un color inventado por proceso.
import QtQuick
import org.dylanos.process

Item {
    id: icon

    property string iconName: ""
    property string iconPath: ""
    property string fallbackText: ""
    property int radius: 7

    implicitWidth: 24
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: icon.radius
        color: Theme.neutralSubtle
        visible: !loader.visible

        Text {
            anchors.centerIn: parent
            text: icon.fallbackText
            color: Theme.textSecondary
            font.family: Theme.uiFont
            font.pixelSize: Math.max(9, icon.height * 0.42)
            font.weight: Font.Bold
        }
    }

    Image {
        id: loader
        anchors.fill: parent
        // Fuente 1: archivo real del tema resuelto por el núcleo.
        // Fuente 2: nombre de icono resuelto por Qt contra el tema activo.
        source: icon.iconPath.length > 0 ? ("file://" + icon.iconPath)
                                         : (icon.iconName.length > 0 ? "image://icon/" + icon.iconName
                                                                     : "")
        visible: status === Image.Ready
        sourceSize.width: icon.width * 2
        sourceSize.height: icon.height * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }
}
