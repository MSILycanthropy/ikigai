import Quickshell
import QtQuick

// A column of task buttons for one pinned group.
Column {
    id: group

    required property var tasks

    signal menuRequested(var task, Item at)
    signal windowsRequested(var task, Item at)
    signal dismissRequested

    spacing: 4

    Repeater {
        model: ScriptModel {
            values: group.tasks
            objectProp: "appId"
        }

        TaskButton {
            onMenuRequested: group.menuRequested(task, this)
            onWindowsRequested: group.windowsRequested(task, this)
            onDismissRequested: group.dismissRequested()
        }
    }
}
