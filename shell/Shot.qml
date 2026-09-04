import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Print. Every screen is captured first, then an overlay per screen shows its frozen
// capture: drag a rectangle, release to hand that crop to satty. Capturing before mapping
// keeps the overlay out of the shot and the screen from changing under the drag.
Scope {
    id: shot

    property bool open: false
    property bool closing: false
    property string stamp: ""
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/ikigai/shot"

    IpcHandler {
        target: "shot"

        function region(): void { shot.begin(); }
    }

    function begin() {
        if (open || freeze.running)
            return;
        stamp = Date.now().toString();
        freeze.command = ["sh", "-c", 'rm -rf "$0" && mkdir -p "$0" && for o; do grim -o "$o" "$0/$o.png" || exit 1; done', dir, ...Quickshell.screens.map(s => s.name)];
        freeze.running = true;
    }

    Process {
        id: freeze
        onExited: (code, status) => {
            if (code === 0)
                shot.open = true;
            else
                console.warn("shot: capture failed", code);
        }
    }

    function commit(window, rect) {
        if (closing)
            return;
        const path = dir + "/shot-" + stamp + ".png";
        const dpr = window.screen.devicePixelRatio;
        console.info("shot commit", window.screen.name, rect.width + "x" + rect.height);
        window.crop.grabToImage(result => {
            if (result.saveToFile(path))
                Apps.spawn(["satty", "--filename", path]);
            else
                console.warn("shot: could not write", path);
        }, Qt.size(Math.round(rect.width * dpr), Math.round(rect.height * dpr)));
        dismiss();
    }

    function cancel() {
        if (closing)
            return;
        console.info("shot cancel");
        dismiss();
    }

    function dismiss() {
        if (!open)
            return;
        closing = true;
        fade.restart();
    }

    Timer {
        id: fade
        interval: Motion.fastEffects
        onTriggered: {
            shot.open = false;
            shot.closing = false;
        }
    }

    Variants {
        model: shot.open ? Quickshell.screens : []

        PanelWindow {
            id: window

            required property var modelData
            readonly property alias crop: crop
            property rect selection: Qt.rect(0, 0, 0, 0)
            property point anchor

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: shot.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ikigai:shot"
            color: "transparent"

            readonly property string frozen: "file://" + shot.dir + "/" + modelData.name + ".png"
            readonly property bool selecting: selection.width > 0 && selection.height > 0

            Item {
                id: content
                anchors.fill: parent
                focus: true
                opacity: shown && !shot.closing ? 1 : 0
                property bool shown: false
                Component.onCompleted: shown = true

                Behavior on opacity {
                    Anim { effects: true; fast: true }
                }

                // Losing focus to something else (a launcher, a lock) abandons the shot.
                readonly property bool active: Window.active
                property bool wasActive: false
                onActiveChanged: {
                    if (active)
                        wasActive = true;
                    else if (wasActive)
                        shot.cancel();
                }

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape: shot.cancel(); break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (window.selecting)
                            shot.commit(window, window.selection);
                        break;
                    default: return;
                    }
                    event.accepted = true;
                }

                Image {
                    anchors.fill: parent
                    source: window.frozen
                    cache: false
                    fillMode: Image.Stretch
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(Theme.colors.surface, 0.6)
                }

                // The undimmed selection: a clipped view of the frozen capture, and what
                // gets grabbed at physical size for the crop.
                Item {
                    id: crop
                    x: window.selection.x
                    y: window.selection.y
                    width: window.selection.width
                    height: window.selection.height
                    clip: true
                    visible: window.selecting

                    Image {
                        x: -crop.x
                        y: -crop.y
                        width: content.width
                        height: content.height
                        source: window.frozen
                        cache: false
                        fillMode: Image.Stretch
                    }
                }

                Rectangle {
                    x: crop.x - border.width
                    y: crop.y - border.width
                    width: crop.width + 2 * border.width
                    height: crop.height + 2 * border.width
                    visible: window.selecting
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.colors.primary
                    radius: border.width
                }

                Rectangle {
                    visible: window.selecting
                    x: Math.min(crop.x + crop.width + 8, content.width - width - 8)
                    y: Math.min(crop.y + crop.height + 8, content.height - height - 8)
                    width: size.implicitWidth + 16
                    height: size.implicitHeight + 8
                    radius: height / 2
                    color: Theme.colors.surfaceContainerHigh

                    Text {
                        id: size
                        anchors.centerIn: parent
                        text: Math.round(window.selection.width * window.screen.devicePixelRatio) + " × " + Math.round(window.selection.height * window.screen.devicePixelRatio)
                        color: Theme.colors.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            shot.cancel();
                            return;
                        }
                        window.anchor = Qt.point(mouse.x, mouse.y);
                        window.selection = Qt.rect(mouse.x, mouse.y, 0, 0);
                    }
                    onPositionChanged: mouse => {
                        if (!(mouse.buttons & Qt.LeftButton))
                            return;
                        const x = Math.max(0, Math.min(mouse.x, content.width));
                        const y = Math.max(0, Math.min(mouse.y, content.height));
                        window.selection = Qt.rect(Math.min(x, window.anchor.x), Math.min(y, window.anchor.y), Math.abs(x - window.anchor.x), Math.abs(y - window.anchor.y));
                    }
                    onReleased: mouse => {
                        if (mouse.button !== Qt.LeftButton)
                            return;
                        if (window.selecting)
                            shot.commit(window, window.selection);
                        else
                            window.selection = Qt.rect(0, 0, 0, 0);
                    }
                }
            }
        }
    }
}
