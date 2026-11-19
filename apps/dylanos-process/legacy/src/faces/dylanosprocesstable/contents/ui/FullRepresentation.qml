/*
 *   SPDX-FileCopyrightText: 2019 Marco Martin <mart@kde.org>
 *   SPDX-FileCopyrightText: 2019 David Edmundson <davidedmundson@kde.org>
 *   SPDX-FileCopyrightText: 2019 Arjen Hiemstra <ahiemstra@heimr.nl>
 *
 *   SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons as KQuickControlsAddons

import org.kde.ksysguard.faces as Faces
import org.kde.ksysguard.process as Process

import org.dylanos.process.table as Table

Faces.SensorFace {
    id: root

    Layout.minimumHeight: Kirigami.Units.gridUnit * 18
    Layout.minimumWidth: Kirigami.Units.gridUnit * 5
    readonly property var config: controller.faceConfiguration

    actions: [
        Kirigami.Action {
            icon.name: "search"
            text: i18nc("@action", "Search")
            displayHint: Kirigami.DisplayHint.KeepVisible
            displayComponent: Kirigami.SearchField {
                text: table.nameFilterString
                onTextEdited: table.nameFilterString = text;
                onAccepted: table.nameFilterString = text;
                Component.onCompleted: forceActiveFocus()
            }
        },

        Kirigami.Action {
            icon.name: "process-stop"
            text: i18nc("@action", "End Process")
            onTriggered: processHelper.sendSignalToSelection(Process.ProcessController.TerminateSignal)
            enabled: table.selection.hasSelection
        },

        // Note: can't use ActionGroup there because of https://bugreports.qt.io/browse/QTBUG-86860
        Kirigami.Action {
            id: listAction
            icon.name: "view-list-details"
            checkable: true
            checked: root.config.viewMode === mode
            visible: table.treeModeSupported
            text: i18nc("@action", "Display as List")

            displayHint: Kirigami.DisplayHint.IconOnly
            property int mode: 0
            onTriggered: {
                root.config.viewMode = mode
                checked = true;
                treeAction.checked = false;
            }
        },

        Kirigami.Action {
            id: treeAction
            icon.name: "view-list-tree"
            checkable: true
            checked: root.config.viewMode === mode
            visible: table.treeModeSupported
            text: i18nc("@action", "Display as Tree")
            displayHint: Kirigami.DisplayHint.IconOnly
            property int mode: 1
            onTriggered: {
                root.config.viewMode = mode;
                checked = true;
                listAction.checked = false;
            }
        },


        Kirigami.Action {
            id: configureColumnsAction
            icon.name: "configure"
            text: i18nc("@action", "Configure Columns…")
            onTriggered: columnDialog.open()
        }
    ]

    contentItem: ColumnLayout {
        id: processPage
        spacing: Kirigami.Units.largeSpacing

        Rectangle {
            id: activityHeader
            Layout.fillWidth: true
            Layout.preferredHeight: 112
            radius: 18
            color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                           Kirigami.Theme.backgroundColor.g,
                           Kirigami.Theme.backgroundColor.b, 0.78)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                  Kirigami.Theme.highlightColor.g,
                                  Kirigami.Theme.highlightColor.b, 0.30)
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 5
                radius: 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Kirigami.Theme.highlightColor }
                    GradientStop { position: 1.0; color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                                                  Kirigami.Theme.highlightColor.g,
                                                                  Kirigami.Theme.highlightColor.b, 0.22) }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.largeSpacing * 1.5
                anchors.rightMargin: Kirigami.Units.largeSpacing * 1.5
                spacing: Kirigami.Units.largeSpacing

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 15
                    color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                   Kirigami.Theme.highlightColor.g,
                                   Kirigami.Theme.highlightColor.b, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                          Kirigami.Theme.highlightColor.g,
                                          Kirigami.Theme.highlightColor.b, 0.22)

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 25
                        height: 25
                        source: "view-process-system"
                        color: Kirigami.Theme.highlightColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing / 2

                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 2
                        text: i18nc("@title:section", "Process activity")
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        text: i18nc("@info", "Find resource-heavy tasks and manage them safely.")
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    visible: processPage.width >= Kirigami.Units.gridUnit * 32
                    radius: height / 2
                    implicitWidth: liveStatus.implicitWidth + Kirigami.Units.largeSpacing * 1.5
                    implicitHeight: 32
                    color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                   Kirigami.Theme.highlightColor.g,
                                   Kirigami.Theme.highlightColor.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                          Kirigami.Theme.highlightColor.g,
                                          Kirigami.Theme.highlightColor.b, 0.24)

                    RowLayout {
                        id: liveStatus
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing

                        Rectangle {
                            Layout.preferredWidth: 7
                            Layout.preferredHeight: 7
                            radius: width / 2
                            color: Kirigami.Theme.highlightColor
                        }

                        Label {
                            text: i18nc("@info:status", "LIVE")
                            font.bold: true
                            font.pixelSize: 11
                            color: Kirigami.Theme.textColor
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 14
            color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                           Kirigami.Theme.backgroundColor.g,
                           Kirigami.Theme.backgroundColor.b, 0.52)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                  Kirigami.Theme.textColor.g,
                                  Kirigami.Theme.textColor.b, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Label {
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    text: i18nc("@label", "VIEW")
                    font.bold: true
                    font.pixelSize: 10
                    color: Kirigami.Theme.disabledTextColor
                }

                Repeater {
                    model: [
                        { label: i18nc("@action:button", "Mine"), icon: "view-process-own", mode: Table.ProcessSortFilterModel.ViewOwn },
                        { label: i18nc("@action:button", "Users"), icon: "view-process-users", mode: Table.ProcessSortFilterModel.ViewUser },
                        { label: i18nc("@action:button", "System"), icon: "view-process-system", mode: Table.ProcessSortFilterModel.ViewSystem },
                        { label: i18nc("@action:button", "All"), icon: "view-process-all", mode: Table.ProcessSortFilterModel.ViewAll }
                    ]

                    delegate: ToolButton {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        checkable: true
                        checked: root.config.userFilterMode === modelData.mode
                        text: modelData.label
                        icon.name: modelData.icon
                        display: root.width < Kirigami.Units.gridUnit * 28
                                 ? AbstractButton.TextOnly
                                 : AbstractButton.TextBesideIcon
                        onClicked: root.config.userFilterMode = modelData.mode
                        background: Rectangle {
                            radius: 10
                            color: parent.checked
                                   ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                             Kirigami.Theme.highlightColor.g,
                                             Kirigami.Theme.highlightColor.b, 0.16)
                                   : "transparent"
                            border.width: parent.checked ? 1 : 0
                            border.color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                                  Kirigami.Theme.highlightColor.g,
                                                  Kirigami.Theme.highlightColor.b, 0.28)
                        }
                    }
                }

                Item { Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.smallSpacing }
            }
        }

        ProcessTableView {
            id: table
            Layout.fillWidth: true
            Layout.fillHeight: true

            flatList: root.config.viewMode === 0
            viewMode: root.config.userFilterMode
            onViewModeChanged: root.config.userFilterMode = viewMode

            columnWidths: root.config.columnWidths
            onColumnWidthsChanged: root.config.columnWidths = columnWidths
            sortName: root.config.sortColumn
            onSortNameChanged: root.config.sortColumn = sortName
            sortOrder: root.config.sortDirection
            onSortOrderChanged: root.config.sortDirection = sortOrder

            onContextMenuRequested: (index, position) => {
                contextMenu.index = index;
                contextMenu.popup(null, position.x, position.y)
            }

            onHeaderContextMenuRequested: (column, columnId, position) => {
                headerContextMenu.columnId = columnId;
                headerContextMenu.popup(null, position)
            }

            enabledColumns: columnDialog.visibleColumns
            columnDisplay: columnDialog.columnDisplay

            Keys.onPressed: event => {
                if (event.matches(StandardKey.Delete)) {
                    processHelper.sendSignalToSelection(Process.ProcessController.TerminateSignal);
                    event.accepted = true;
                } else if ((event.modifiers & Qt.ShiftModifier) && (event.key == Qt.Key_Delete)) {
                    processHelper.sendSignalToSelection(Process.ProcessController.KillSignal);
                    event.accepted = true;
                }
            }
        }
    }

    Menu {
        id: contextMenu

        property var index

//         MenuItem { text: i18n("Set priority...") }
        Menu {
            title: i18nc("@action:inmenu", "Send Signal")
            icon.name: "send_signal-symbolic"

            MenuItem {
                text: i18nc("@action:inmenu Send Signal", "Suspend (STOP)");
                onTriggered: processHelper.sendSignalToSelection(Process.ProcessController.StopSignal)
            }
            MenuItem {
                text: i18nc("@action:inmenu Send Signal", "Continue (CONT)")
                onTriggered: processHelper.sendSignalToSelection(Process.ProcessController.ContinueSignal)
            }
            MenuItem {
                text: i18nc("@action:inmenu Send Signal", "Hangup (HUP)")
                onTriggered: processHelper.sendSignalToSelection(Process.ProcessController.HangupSignal)
            }
            MenuItem {
                text: i18nc("@action:inmenu Send Signal", "Interrupt (INT)")
                onTriggered: processHelper.sendSignalToSelection(Process.ProcessController.InterruptSignal)
            }
            MenuItem {
                text: i18nc("@action:inmenu  Send Signal", "Terminate (TERM)")
                onTriggered: processHelper.sendSignalToSelection(Process.ProcessController.TerminateSignal)
            }
            MenuItem {
                text: i18nc("@action:inmenu Send Signal", "Kill (KILL)")
                onTriggered: processHelper.sendSignalToSelection(Process.ProcessController.KillSignal)
            }
            MenuItem {
                text: i18nc("@action:inmenu Send Signal", "User 1 (USR1)")
                onTriggered: processHelper.sendSignalToSelection(Process.ProcessController.User1Signal)
            }
            MenuItem {
                text: i18nc("@action:inmenu  Send Signal", "User 2 (USR2)")
                onTriggered: processHelper.sendSignalToSelection(Process.ProcessController.User2Signal)
            }
        }
        MenuItem {
            icon.name: "edit-copy";
            text: i18nc("@action:inmenu", "Copy Current Column")
            onTriggered: clipboard.content = table.model.data(contextMenu.index)

            KQuickControlsAddons.Clipboard { id: clipboard }
        }
//         MenuItem { text: i18nc("@action:inmenu", "Show Application Window") }
        MenuSeparator { }
        MenuItem {
            icon.name: "process-stop";
            text: i18ncp("@action:inmenu", "End Process", "End %1 Processes", killDialog.items.length);
            onTriggered: {
                processHelper.sendSignalToSelection(Process.ProcessController.TerminateSignal)
            }

        }
    }

    Menu {
        id: headerContextMenu
        property string columnId

        MenuItem {
            text: i18nc("@action:inmenu hide column", "Hide")
            icon.name: "hide_table_column"
            onClicked: columnDialog.hideColumn(headerContextMenu.columnId)
        }
        MenuItem {
            text: i18nc("@action:inmenu", "Configure Columns…")
            icon.name: "configure"
            onClicked: columnDialog.open()
        }
    }

    Table.KillDialog {
        id: killDialog

        property int signalToSend
        allowDoNotAskAgain: false

        title: signalToSend === Process.ProcessController.KillSignal
               ? i18ncp("@title:window", "Forcibly End Process", "Forcibly End %1 Processes", items.length)
               : i18ncp("@title:window", "End Process", "End %1 Processes", items.length)
        killButtonText: signalToSend === Process.ProcessController.KillSignal
                        ? i18ncp("@action:button", "Forcibly End Process", "Forcibly End Processes", items.length)
                        : i18ncp("@action:button", "End Process", "End Processes", items.length)
        killButtonIcon: "process-stop"
        questionText: signalToSend === Process.ProcessController.KillSignal
                      ? i18np("Forcibly end (SIGKILL) this process? Unsaved work may be lost.",
                              "Forcibly end (SIGKILL) these %1 processes? Unsaved work may be lost.",
                              items.length)
                      : i18np("End this process? Unsaved work may be lost.",
                              "End these %1 processes? Unsaved work may be lost.",
                              items.length)

        items: table.selectedProcesses

        delegate: Kirigami.Padding {
            horizontalPadding: Kirigami.Units.largeSpacing
            verticalPadding: Kirigami.Units.smallSpacing

            contentItem: Kirigami.TitleSubtitle {
                title: modelData.name
                subtitle: i18nc("@item:intable %1 is process id, %2 is user name", "Process ID %1, owned by %2", modelData.pid, modelData.username)
            }
        }

        onAccepted: {
            var pids = items.map(i => i.pid)
            processHelper.sendSignal(pids, signalToSend)
        }
    }

    Process.ProcessController {
        id: processHelper

        property var killSignals: [
            Process.ProcessController.TerminateSignal,
            Process.ProcessController.KillSignal
        ]

        function sendSignalToSelection(sig) {
            if (killSignals.includes(sig)) {
                killDialog.signalToSend = sig
                killDialog.open()
            } else {
                var pids = table.selectedProcesses.map(i => i.pid)
                sendSignal(pids, sig);
            }
        }
    }

    Table.ColumnConfigurationDialog {
        id: columnDialog

        parent: root.Window.window?.overlay

        sourceModel: table.processModel.attributesModel

        sortedColumns: root.config.sortedColumns

        fixedColumns: ["name"]

        onAccepted: {
            root.config.sortedColumns = sortedColumns
            root.config.columnDisplay = JSON.stringify(columnDisplay)
        }

        Component.onCompleted: {
            setColumnDisplay(JSON.parse(root.config.columnDisplay))
        }
    }
}
