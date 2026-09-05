import QtQuick

// One card beside the rail that slides to whichever button asked for it and resizes to its
// content, so switching between menus is a morph rather than a close and a reopen. Bar
// masks input to the frame and draws it as a blob; leaving closes it after a grace period.
Item {
    id: popouts

    property Item anchorItem: null
    property bool hovered: false
    property Item current: null
    readonly property bool workspacesOpen: current === workspaces
    readonly property bool volumeOpen: current === volume
    readonly property bool batteryOpen: current === battery
    readonly property Item card: frame.height > 0 ? frame : null

    width: 280

    // Right-clicking the app whose menu is open closes it, like a toggle.
    function openMenu(task, at) {
        if (current === menu && menu.task.appId === task.appId)
            close();
        else
            show(menu, at, task);
    }

    function openWindows(task, at) {
        if (current === menu)
            return;
        if (task.windows.length > 0)
            show(windows, at, task);
        else if (current === windows)
            close();
    }

    function toggleWorkspaces(at) {
        if (current === workspaces)
            close();
        else
            show(workspaces, at, null);
    }

    function openTray(item, at) {
        if (current === tray && tray.task === item)
            close();
        else
            show(tray, at, item);
    }

    function toggleBattery(at) {
        if (current === battery)
            close();
        else
            show(battery, at, null);
    }

    function toggleVolume(at) {
        if (current === volume)
            close();
        else
            show(volume, at, null);
    }

    function show(content, at, task) {
        content.task = task;
        anchorItem = at;
        current = content;
    }

    function close() {
        current = null;
    }

    onHoveredChanged: hovered ? leave.stop() : leave.restart()

    Timer {
        id: leave
        interval: Motion.grace
        onTriggered: popouts.close()
    }

    Item {
        id: frame

        // The content being shown, or the last one while the frame shrinks away.
        property Item content: menu
        property real centre: popouts.anchorItem ? popouts.anchorItem.mapToItem(popouts, 0, popouts.anchorItem.height / 2).y : 0

        width: popouts.current ? content.implicitWidth : 0
        height: popouts.current ? content.implicitHeight : 0
        y: Math.max(Theme.border, Math.min(popouts.height - Theme.border - height, centre - height / 2))
        clip: true

        Behavior on width {
            Anim {}
        }

        Behavior on height {
            Anim {}
        }

        // A fresh card grows in place; only an open one slides to the next button.
        Behavior on centre {
            enabled: frame.height > 0
            Anim {}
        }

        TaskMenu {
            id: menu
            shown: popouts.current === menu
            onDone: popouts.close()
        }

        TaskWindows {
            id: windows
            shown: popouts.current === windows
            onDone: popouts.close()
        }

        Workspaces {
            id: workspaces
            shown: popouts.current === workspaces
            onDone: popouts.close()
        }

        TrayMenu {
            id: tray
            shown: popouts.current === tray
            onDone: popouts.close()
        }

        VolumeCard {
            id: volume
            shown: popouts.current === volume
            onDone: popouts.close()
        }

        BatteryCard {
            id: battery
            shown: popouts.current === battery
            onDone: popouts.close()
        }
    }

    onCurrentChanged: if (current) frame.content = current
}
