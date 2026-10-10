/* Slideshow del instalador DylanOS 1.0 Beta (Calamares, API 2).
 * Identidad Crimson sobre negro, tipografía minimalista. */

import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    /* Avance automático suave entre diapositivas (fallback). */
    Timer {
        id: advanceTimer
        interval: 7000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    /* Fondo negro DylanOS detrás de todas las diapositivas. */
    Rectangle {
        anchors.fill: parent
        color: "#0A0A0A"
        z: -1
    }

    /* Puntos de progreso en la parte inferior. */
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        spacing: 10

        Repeater {
            model: 6 /* Número estándar de diapositivas de Calamares */
            delegate: Rectangle {
                width: 8
                height: 8
                radius: 4
                color: index === presentation.currentSlide ? "#DC143C" : "#2E2E33"

                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }

    /* Estilo común para el contenido de las diapositivas */
    component SlideContent: Column {
        id: content
        property string title: ""
        property string body: ""

        anchors.centerIn: parent
        spacing: 18
        width: Math.min(parent.width * 0.7, 620)

        Text {
            text: content.title
            color: "#F5F5F7"
            font.family: "Inter"
            font.pixelSize: 34
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Text {
            text: content.body
            color: "#98989F"
            font.family: "Inter"
            font.pixelSize: 18
            font.weight: Font.Light
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }

    /* Las diapositivas serán pobladas por Calamares a través de API 2 */
    Slide {
        SlideContent { title: "Bienvenido a DylanOS"; body: "Un sistema operativo moderno, rápido y elegante basado en Debian." }
    }
    Slide {
        SlideContent { title: "Tu espacio de trabajo"; body: "Workspace integra archivos, notas, desarrollo y monitoreo en una sola app." }
    }
    Slide {
        SlideContent { title: "Diseñado para ti"; body: "Interfaz oscura con acentos Crimson. Moderna, limpia y sin distracciones." }
    }
    Slide {
        SlideContent { title: "Software al alcance"; body: "Instala aplicaciones fácilmente desde el App Center de DylanOS." }
    }
    Slide {
        SlideContent { title: "Potenciado por Debian"; body: "Estabilidad y seguridad de Debian 13 Trixie como base sólida." }
    }
    Slide {
        SlideContent { title: "¡Casi listo!"; body: "Tu nuevo sistema se está instalando. En unos minutos podrás disfrutarlo." }
    }

    /* API 2: el slideshow se activa y desactiva con la página de progreso. */
    function onActivate() {
        presentation.currentSlide = 0;
    }

    function onLeave() {
    }
}
