import Quickshell
import QtQuick

// The sidebar: notification history under a do-not-disturb toggle and a clear button,
// then a month calendar. Hangs out of the frame's right border; Bar draws it as a blob
// and, while it is open, takes input over the whole screen so a click elsewhere closes it.
Item {
    id: sidebar

    readonly property bool open: Notifs.sidebarOpen
    readonly property int pad: Math.round(16 * Config.scale)

    width: Math.round(360 * Config.scale)
    opacity: open ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        Anim { effects: true }
    }

    Column {
        id: column
        anchors {
            fill: parent
            margins: sidebar.pad
        }
        spacing: sidebar.pad

        Item {
            id: header
            width: parent.width
            height: Theme.barWidth - 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Theme.colors.fg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize + 1
                font.weight: Font.Medium
            }

            Row {
                anchors.right: parent.right
                spacing: 4

                BarButton {
                    checked: Config.dnd
                    onClicked: Config.setDnd(!Config.dnd)

                    Glyph {
                        anchors.centerIn: parent
                        name: Config.dnd ? "bell-slash" : "bell"
                        size: 18
                        color: Config.dnd ? Theme.colors.primary : Theme.colors.fgVariant
                    }
                }

                BarButton {
                    visible: Notifs.history.length > 0
                    onClicked: Notifs.clear()

                    Glyph {
                        anchors.centerIn: parent
                        name: "broom"
                        size: 18
                        color: Theme.colors.fgVariant
                    }
                }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - header.height - calendar.height - 2 * column.spacing
            clip: true
            spacing: Math.round(8 * Config.scale)
            model: ScriptModel {
                values: Notifs.history
            }

            Text {
                anchors.centerIn: parent
                text: Config.dnd ? "Do not disturb is on" : "No notifications"
                visible: Notifs.history.length === 0
                color: Theme.colors.outline
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
            }

            delegate: Rectangle {
                id: entry

                required property var modelData
                readonly property int inset: Math.round(12 * Config.scale)
                readonly property int iconSize: Math.round(28 * Config.scale)

                width: list.width
                height: body.implicitHeight + 2 * inset
                radius: Theme.radius + 4
                color: Theme.colors.surfaceContainerLow

                StateLayer {
                    radius: parent.radius
                    hovered: entryHover.hovered
                }

                HoverHandler {
                    id: entryHover
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Notifs.remove(entry.modelData)
                }

                Row {
                    id: body
                    x: entry.inset
                    y: entry.inset
                    width: parent.width - 2 * entry.inset
                    spacing: Math.round(10 * Config.scale)

                    AppIcon {
                        source: entry.modelData.icon
                        size: entry.iconSize
                    }

                    Column {
                        width: parent.width - entry.iconSize - parent.spacing
                        spacing: 2

                        Item {
                            width: parent.width
                            height: app.implicitHeight

                            Text {
                                id: app
                                text: entry.modelData.appName
                                color: Theme.colors.fgVariant
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 3
                            }

                            Text {
                                anchors.right: parent.right
                                text: Qt.formatTime(entry.modelData.time, "HH:mm")
                                color: Theme.colors.outline
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 3
                            }
                        }

                        Text {
                            width: parent.width
                            text: entry.modelData.summary
                            color: Theme.colors.fg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            font.weight: Font.Medium
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: entry.modelData.body
                            visible: text !== ""
                            color: Theme.colors.fgVariant
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Calendar {
            id: calendar
            width: parent.width
        }
    }
}
