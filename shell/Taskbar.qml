import Quickshell
import QtQuick

Column {
    id: taskbar

    property bool workspacesOpen: false

    signal menuRequested(var task, Item at)
    signal windowsRequested(var task, Item at)
    signal workspacesRequested(Item at)

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
        id: taskView
        checked: taskbar.workspacesOpen
        onClicked: taskbar.workspacesRequested(taskView)

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

    TaskGroup {
        tasks: Tasks.top
        onMenuRequested: (task, at) => taskbar.menuRequested(task, at)
        onWindowsRequested: (task, at) => taskbar.windowsRequested(task, at)
    }
}
