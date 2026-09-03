import Quickshell
import QtQuick

// The windows of one app: click focuses, middle-click closes. Room above each title is
// reserved for a preview once the bridge can capture windows.
PopupCard {
    id: card

    readonly property var windows: task ? Bridge.windows.filter(w => w.appId === task.appId) : []

    onWindowsChanged: if (shown && windows.length === 0) done()

    implicitWidth: 280
    implicitHeight: rows.implicitHeight + 12

    Column {
        id: rows
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        Repeater {
            model: ScriptModel {
                values: card.windows
                objectProp: "id"
            }

            Item {
                id: row
                required property var modelData
                readonly property bool focused: modelData.states.includes("activated")

                width: rows.width
                height: 36

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: Theme.colors.surface
                    opacity: rowHover.hovered ? 1 : row.focused ? 0.5 : 0

                    Behavior on opacity {
                        Anim { effects: true; fast: true }
                    }
                }

                AppIcon {
                    id: icon
                    anchors {
                        left: parent.left
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    size: 16
                    source: Quickshell.iconPath(Apps.iconFor(card.task.appId), "application-x-executable")
                }

                Text {
                    anchors {
                        left: icon.right
                        leftMargin: 10
                        right: closeGlyph.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: row.modelData.title
                    elide: Text.ElideRight
                    color: Theme.colors.fg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                }

                Glyph {
                    id: closeGlyph
                    anchors {
                        right: parent.right
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: "󰅖"
                    size: 14
                    color: Theme.colors.muted
                    opacity: rowHover.hovered ? 1 : 0

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: Bridge.close(row.modelData.id)
                    }
                }

                HoverHandler {
                    id: rowHover
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 30
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            Bridge.close(row.modelData.id);
                            return;
                        }
                        card.done();
                        Bridge.activate(row.modelData.id);
                    }
                }
            }
        }
    }
}
