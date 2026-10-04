import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_iconSize: iconSizeField.value
    property alias cfg_hoverSize: hoverSizeField.value
    property alias cfg_iconSpacing: spacingField.value
    property alias cfg_dockPadding: paddingField.value
    property alias cfg_backgroundOpacity: opacityField.value
    property alias cfg_cornerRadius: radiusField.value
    property string cfg_accentColor
    property alias cfg_showIndicator: indicatorField.checked

    QQC2.SpinBox {
        id: iconSizeField
        Kirigami.FormData.label: "Tamano de icono:"
        from: 24
        to: 96
    }

    QQC2.SpinBox {
        id: hoverSizeField
        Kirigami.FormData.label: "Tamano al pasar el cursor:"
        from: 24
        to: 140
    }

    QQC2.SpinBox {
        id: spacingField
        Kirigami.FormData.label: "Espacio entre iconos:"
        from: 0
        to: 32
    }

    QQC2.SpinBox {
        id: paddingField
        Kirigami.FormData.label: "Margen interno del dock:"
        from: 0
        to: 64
    }

    QQC2.Slider {
        id: opacityField
        Kirigami.FormData.label: "Opacidad del fondo:"
        from: 0.0
        to: 1.0
        stepSize: 0.05
    }

    QQC2.SpinBox {
        id: radiusField
        Kirigami.FormData.label: "Radio de esquina:"
        from: 0
        to: 48
    }

    RowLayout {
        Kirigami.FormData.label: "Color de acento:"

        Rectangle {
            width: 24
            height: 24
            radius: 6
            color: page.cfg_accentColor
            border.color: "#ffffff"
            border.width: 1
        }

        QQC2.Button {
            text: "Elegir color..."
            onClicked: colorDialog.open()
        }
    }

    QQC2.CheckBox {
        id: indicatorField
        Kirigami.FormData.label: "Indicador de app abierta:"
        text: "Mostrar rayita bajo apps en ejecucion"
    }

    ColorDialog {
        id: colorDialog
        selectedColor: page.cfg_accentColor
        onAccepted: page.cfg_accentColor = selectedColor
    }
}
