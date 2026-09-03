import Quickshell
import QtQuick

PopupCard {
    id: popup

    property bool active: false
    property var task: null

    shown: active
    implicitWidth: 260
    implicitHeight: list.implicitHeight + 12

    Column {
        id: list
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        Repeater {
            model: Bridge.workspaces

            Item {
                id: row
                required property var modelData
                readonly property var windows: Bridge.windows.filter(w => w.workspaces.includes(modelData.id))

                width: list.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius - 2
                    color: Theme.colors.surface
                    opacity: row.modelData.active ? 1 : rowHover.hovered ? 0.5 : 0

                    Behavior on opacity {
                        Anim { effects: true; fast: true }
                    }
                }

                Text {
                    id: name
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: row.modelData.name
                    color: row.modelData.active ? Theme.colors.accent : Theme.colors.fg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.bold: row.modelData.active
                }

                HoverHandler {
                    id: rowHover
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        popup.active = false;
                        Bridge.activateWorkspace(row.modelData.id);
                    }
                }

                Row {
                    anchors {
                        left: name.right
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6

                    Repeater {
                        model: row.windows

                        AppIcon {
                            id: icon
                            required property var modelData

                            source: Quickshell.iconPath(Apps.iconFor(modelData.appId), "application-x-executable")

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    popup.active = false;
                                    Bridge.activate(icon.modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
