/*
 *   Copyright 2016 David Edmundson <davidedmundson@kde.org>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU Library General Public License
 *   version 2 or later.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

ColumnLayout {
    id: clockContainer

    spacing: 4

    FontLoader {
        id: fontbold
        source: "../fonts/SFUIText-Semibold.otf"
    }

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    // Panel glass
    Rectangle {
        id: glassPanel

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 360
        Layout.preferredHeight: 150

        radius: 32

        color: "#35101010"

        border.width: 1
        border.color: "#35E50914"

        // Fecha
        Label {
            id: dateLabel

            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter

            text: Qt.formatDateTime(new Date(), "dddd, MMMM d")

            color: "#FFFFFF"
            opacity: 0.58

            font.family: fontbold.name
            font.pointSize: 13
            font.weight: Font.Normal
            font.capitalization: Font.Capitalize

            horizontalAlignment: Text.AlignHCenter
        }

        // Hora
        Label {
            id: timeLabel

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 10

            text: Qt.formatDateTime(new Date(), "h:mm")

            color: "#E50914"
            opacity: 0.95

            font.family: fontbold.name
            font.pointSize: 62
            font.weight: Font.Normal

            horizontalAlignment: Text.AlignHCenter

            style: softwareRendering ? Text.Outline : Text.Normal
            styleColor: softwareRendering
            ? "#20000000"
            : "transparent"
        }
    }

    Plasma5Support.DataSource {
        id: timeSource

        engine: "time"
        connectedSources: ["Local"]

        interval: 1000
    }
}
