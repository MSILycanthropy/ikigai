import Quickshell
import QtQuick

PopupCard {
    id: popup


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

                StateLayer {
                    active: row.modelData.active
                    hovered: rowHover.hovered
                }

                Text {
                    id: name
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: row.modelData.name
                    color: row.modelData.active ? Theme.colors.primary : Theme.colors.fg
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
                        popup.done();
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
                                    popup.done();
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
