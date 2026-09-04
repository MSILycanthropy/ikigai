import Quickshell
import QtQuick

Column {
    id: taskbar

    property bool workspacesOpen: false
    property alias taskView: taskViewButton

    signal menuRequested(var task, Item at)
    signal windowsRequested(var task, Item at)
    signal workspacesRequested(Item at)
    signal dismissRequested

    spacing: 4

    BarButton {
        onClicked: {
            taskbar.dismissRequested();
            Quickshell.execDetached(["vicinae", "toggle"]);
        }

        Glyph {
            anchors.centerIn: parent
            name: "squares-four"
            size: Theme.iconSize
        }
    }

    BarButton {
        id: taskViewButton
        checked: taskbar.workspacesOpen
        onClicked: taskbar.workspacesRequested(taskViewButton)

        Glyph {
            anchors.centerIn: parent
            name: "cards"
            size: Theme.iconSize
            fill: taskbar.workspacesOpen
        }
    }

    TaskGroup {
        tasks: Tasks.top
        onMenuRequested: (task, at) => taskbar.menuRequested(task, at)
        onWindowsRequested: (task, at) => taskbar.windowsRequested(task, at)
        onDismissRequested: taskbar.dismissRequested()
    }
}
