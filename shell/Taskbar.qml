import Quickshell
import QtQuick

Row {
    readonly property bool menuOpen: menu.visible || workspaces.visible

    spacing: 4

    BarButton {
        onClicked: Quickshell.execDetached(["vicinae", "toggle"])

        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: 2

            Repeater {
                model: 4

                Rectangle {
                    width: 7
                    height: 7
                    radius: 2
                    color: Theme.colors.accent
                }
            }
        }
    }

    BarButton {
        onClicked: Quickshell.execDetached(["vicinae", "toggle"])

        Rectangle {
            x: 1
            y: 1
            width: 11
            height: 11
            radius: 5.5
            color: "transparent"
            border.width: 2
            border.color: Theme.colors.fg
        }

        Rectangle {
            x: 10
            y: 11
            width: 7
            height: 2
            radius: 1
            rotation: 45
            color: Theme.colors.fg
        }
    }

    BarButton {
        id: taskView
        checked: workspaces.visible
        onClicked: workspaces.visible = !workspaces.visible

        Rectangle {
            x: 0
            y: 5
            width: 13
            height: 13
            radius: 3
            color: "transparent"
            border.width: 2
            border.color: Theme.colors.fg
        }

        Rectangle {
            x: 5
            y: 0
            width: 13
            height: 13
            radius: 3
            color: Theme.colors.bg
            border.width: 2
            border.color: Theme.colors.fg
        }
    }

    Repeater {
        model: ScriptModel {
            values: Tasks.items
            objectProp: "appId"
        }

        TaskButton {
            onMenuRequested: menu.open(task, this)
        }
    }

    TaskMenu {
        id: menu
    }

    Workspaces {
        id: workspaces
        anchor.item: taskView
    }
}
