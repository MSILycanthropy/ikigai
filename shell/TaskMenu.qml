import Quickshell
import QtQuick

PopupWindow {
    id: menu

    property var task: null
    readonly property var entries: task ? build(task, Bridge.workspaces) : []

    function open(forTask, at) {
        task = forTask;
        anchor.item = at;
        visible = true;
    }

    function build(task, workspaces) {
        const name = task.entry ? task.entry.name : task.appId;
        const list = [
            { label: name, run: () => task.entry && Apps.launch(task.entry) },
            { label: task.pinned ? "Unpin from taskbar" : "Pin to taskbar", run: () => task.pinned ? Config.unpin(task.appId) : Config.pin(task.appId) }
        ];
        const window = task.windows.find(w => w.states.includes("activated")) || task.windows[0];
        if (window) {
            for (const ws of workspaces.filter(ws => !window.workspaces.includes(ws.id)))
                list.push({ label: "Move to workspace " + ws.name, run: () => Bridge.moveToWorkspace(window.id, ws.id) });
            list.push({ label: task.windows.length > 1 ? "Close all windows" : "Close window", run: () => task.windows.forEach(w => Bridge.close(w.id)) });
        }
        return list;
    }

    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    grabFocus: true
    color: "transparent"
    implicitWidth: 220
    implicitHeight: rows.implicitHeight + 12 + 2 * Motion.slack

    PopupCard {
        shown: menu.visible

        Column {
            id: rows
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 6
            }

            Repeater {
                model: menu.entries

                Item {
                    id: row
                    required property var modelData

                    width: rows.width
                    height: 32

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius - 2
                        color: Theme.colors.surface
                        opacity: rowHover.hovered ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: Motion.quick }
                        }
                    }

                    Text {
                        anchors.fill: parent
                        leftPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        text: row.modelData.label
                        color: Theme.colors.fg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                    }

                    HoverHandler {
                        id: rowHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            menu.visible = false;
                            row.modelData.run();
                        }
                    }
                }
            }
        }
    }
}
