import Quickshell
import QtQuick

Item {
    id: button

    required property var modelData
    readonly property var task: modelData
    readonly property bool running: task.windows.length > 0
    readonly property bool active: task.windows.some(w => w.states.includes("activated"))

    signal menuRequested
    signal windowsRequested

    implicitWidth: Theme.barWidth - 8
    implicitHeight: Theme.barWidth - 8

    scale: press.pressed ? 0.88 : 1

    Behavior on scale {
        Anim { fast: true }
    }

    StateLayer {
        hovered: hover.hovered
        pressed: press.pressed
    }

    Glyph {
        anchors.centerIn: parent
        name: Apps.glyphFor(button.task.appId)
        size: Theme.iconSize
        fill: button.active
        color: button.active ? Theme.colors.accent : button.running ? Theme.colors.fg : Theme.colors.muted

        Behavior on color {
            ColorAnimation { duration: Motion.fastEffects }
        }
    }

    // Running mark on the rail edge: short while running, long while focused.
    Rectangle {
        anchors {
            left: parent.left
            leftMargin: -3
            verticalCenter: parent.verticalCenter
        }
        width: 2
        height: button.active ? 16 : 6
        radius: 1
        color: Theme.colors.accent
        visible: button.running

        Behavior on height {
            Anim { fast: true }
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered && button.running)
                linger.restart();
            else
                linger.stop();
        }
    }

    // Resting on a running app opens its window list, like a taskbar thumbnail strip.
    Timer {
        id: linger
        interval: 300
        onTriggered: button.windowsRequested()
    }

    MouseArea {
        id: press
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
