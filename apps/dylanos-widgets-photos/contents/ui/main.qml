pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import Qt.labs.folderlistmodel
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Fotos.
 *
 * Carrusel de imágenes de una carpeta local del usuario. La carpeta se
 * configura en el applet (por defecto ~/Imágenes). Sin carpeta o sin
 * imágenes lo dice; no incluye fotos de ejemplo.
 *
 * Requiere qml6-module-qt-labs-folderlistmodel (añadido al perfil base).
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.mediumWide, Tokens.large]
    readonly property string defaultSize: Tokens.mediumWide
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    property string folder: Plasmoid.configuration.folder || ""

    // StandardPaths no existe en QML puro. El directorio de imágenes se
    // resuelve leyendo HOME con el DataSource real (echo $HOME), no con una
    // propiedad inventada. Mientras llega, la carpeta queda vacía y el widget
    // muestra su estado explícito.
    property string homeDir: ""

    readonly property string picturesDir: root.folder.length > 0
                                          ? "file://" + root.folder
                                          : (root.homeDir.length > 0
                                             ? "file://" + root.homeDir + "/Imágenes" : "")

    P5Support.DataSource {
        id: homeReader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const value = (data.stdout || "").trim();
            if (value.length > 0)
                root.homeDir = value;
        }
    }

    Component.onCompleted: homeReader.connectSource("sh -c 'printf %s \"$HOME\"'")
    readonly property bool hasPhotos: photoModel.count > 0

    FolderListModel {
        id: photoModel
        folder: root.picturesDir
        showDirs: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.avif"]
    }

    property int currentIndex: 0

    Timer {
        interval: 8000
        running: root.hasPhotos
        repeat: true
        onTriggered: root.currentIndex = (root.currentIndex + 1) % Math.max(1, photoModel.count)
    }

    fullRepresentation: Item {
        implicitWidth: root.width > 0 ? root.width
                                      : Tokens.widthFor(Tokens.mediumWide, root.cellSize)
        implicitHeight: root.cellSize

        WidgetCard {
            anchors.fill: parent
            variant: PlasmaCore.Theme.textColor.hsvValue > 0.5 ? Tokens.variantDark : Tokens.variantLight
        }

        Image {
            anchors.fill: parent
            anchors.margins: 2
            source: root.hasPhotos ? photoModel.get(root.currentIndex, "fileURL") : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: root.hasPhotos
            // Recorte redondeado coherente con la tarjeta.
            layer.enabled: false
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - Tokens.space6
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: !root.hasPhotos
            text: "Sin fotos en " + (root.folder.length > 0 ? root.folder : "~/Imágenes")
                  + ". Configura una carpeta en el applet."
            color: PlasmaCore.Theme.disabledTextColor
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSizeCaption
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.hasPhotos)
                    root.currentIndex = (root.currentIndex + 1) % photoModel.count;
            }
        }
    }
}
