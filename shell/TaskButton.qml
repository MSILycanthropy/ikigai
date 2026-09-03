import Quickshell
import QtQuick

Item {
    id: button

    required property var modelData
    readonly property var task: modelData
    readonly property bool running: task.windows.length > 0
    readonly property bool active: task.windows.some(w => w.states.includes("activated"))

    signal menuRequested

    implicitWidth: Theme.barWidth - 8
    implicitHeight: Theme.barWidth - 8

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.colors.surface
        opacity: hover.hovered ? 1 : 0

        Behavior on opacity {
            Anim { effects: true; fast: true }
        }
    }

    AppIcon {
        anchors.centerIn: parent
        source: Quickshell.iconPath(Apps.iconFor(button.task.appId), "application-x-executable")
    }

    Rectangle {
        anchors {
            bottom: parent.bottom
            bottomMargin: 3
            horizontalCenter: parent.horizontalCenter
        }
        width: button.active ? 16 : 6
        height: 3
        radius: height / 2
        color: Theme.colors.accent
        visible: button.running

        Behavior on width {
            Anim { fast: true }
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                button.primary();
            else if (mouse.button === Qt.MiddleButton)
                button.closeWindow();
            else
                button.menuRequested();
        }
    }

    function primary() {
        if (!running) {
            launch();
            return;
        }
        const windows = task.windows;
        const current = windows.findIndex(w => w.states.includes("activated"));
        if (current < 0)
            Bridge.activate(windows[0].id);
        else if (windows.length === 1)
            Bridge.minimize(windows[0].id);
        else
            Bridge.activate(windows[(current + 1) % windows.length].id);
    }

    function closeWindow() {
        const target = task.windows.find(w => w.states.includes("activated")) || task.windows[0];
        if (target)
            Bridge.close(target.id);
    }

    function launch() {
        if (task.entry)
            Apps.launch(task.entry);
    }
}
