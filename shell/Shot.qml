import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Print. An overlay per screen maps transparent with a blank cursor, every screen is
// captured (cosmic-comp paints the pointer into captures whatever grim asks, so it has
// to be hidden first), then the frozen capture fades in with a pill to pick what to
// capture (a region, a screen) and what to do with it (snip: clipboard +
// ~/Pictures/Screenshots; edit: satty). Freezing keeps the screen from changing under
// the drag.
Scope {
    id: shot

    property bool open: false
    property bool frozen: false
    property bool closing: false
    property bool flashing: false
    property string mode: "region"
    property string action: "snip"
    property string stamp: ""
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/ikigai/shot"

    readonly property var modes: [
        { id: "region", icon: "selection", label: "Region", key: Qt.Key_1 },
        { id: "screen", icon: "monitor", label: "Screen", key: Qt.Key_3 }
    ]
    readonly property var actions: [
        { id: "snip", icon: "copy", label: "Snip" },
        { id: "edit", icon: "pencil-simple", label: "Edit" }
    ]

    IpcHandler {
        target: "shot"

        function region(): void { shot.begin("region", "snip"); }
        function screen(): void { shot.begin("screen", "snip"); }
    }

    function begin(mode, action) {
        if (open)
            return;
        shot.mode = mode;
        shot.action = action;
        stamp = Date.now().toString();
        frozen = false;
        open = true;
        settle.restart();
    }

    // A couple of frames for the overlays to map and the pointer to pick up the blank cursor.
    Timer {
        id: settle
        interval: 80
        onTriggered: {
            freeze.command = ["sh", "-c", 'rm -rf "$0" && mkdir -p "$0" && for o; do grim -o "$o" "$0/$o.png" || exit 1; done', shot.dir, ...Quickshell.screens.map(s => s.name)];
            freeze.running = true;
        }
    }

    Process {
        id: freeze
        onExited: (code, status) => {
            if (code === 0) {
                shot.frozen = true;
            } else {
                console.warn("shot: capture failed", code);
                shot.cancel();
            }
        }
    }

    function fileName() {
        const pad = n => (n < 10 ? "0" : "") + n;
        const d = new Date();
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + "_" + pad(d.getHours()) + "-" + pad(d.getMinutes()) + "-" + pad(d.getSeconds()) + ".png";
    }

    function commit(window, rect) {
        if (!frozen || closing || flashing)
            return;
        const path = dir + "/shot-" + stamp + ".png";
        const dpr = window.screen.devicePixelRatio;
        const action = shot.action;
        console.info("shot", action, window.screen.name, rect.width + "x" + rect.height);
        window.crop.grabToImage(result => {
            if (!result.saveToFile(path)) {
                console.warn("shot: could not write", path);
                return;
            }
            if (action === "edit")
                Apps.spawn(["satty", "--filename", path]);
            else
                Apps.spawn(["sh", "-c", 'd="$(xdg-user-dir PICTURES)/Screenshots" && mkdir -p "$d" && cp "$0" "$d/$1" && wl-copy --type image/png < "$0"', path, fileName()]);
        }, Qt.size(Math.round(rect.width * dpr), Math.round(rect.height * dpr)));
        if (action === "snip") {
            flashing = true;
            flash.restart();
        } else {
            dismiss();
        }
    }

    function cancel() {
        if (closing)
            return;
        console.info("shot cancel");
        if (frozen)
            dismiss();
        else
            open = false;
    }

    function dismiss() {
        if (!open)
            return;
        closing = true;
        fade.restart();
    }

    Timer {
        id: flash
        interval: 220
        onTriggered: {
            shot.flashing = false;
            shot.dismiss();
        }
    }

    Timer {
        id: fade
        interval: Motion.fastEffects
        onTriggered: {
            shot.open = false;
            shot.closing = false;
        }
    }

    component PillButton: Item {
        id: button

        property string icon
        property string label
        property bool checked: false

        signal clicked

        implicitWidth: row.implicitWidth + 20
        implicitHeight: Math.round(30 * Config.scale)

        StateLayer {
            radius: height / 2
            hovered: hover.hovered
            pressed: press.pressed
            active: button.checked
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Glyph {
                name: button.icon
                size: Theme.iconSize - 2
                fill: button.checked
                color: button.checked ? Theme.colors.primary : Theme.colors.fg
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: button.label
                color: button.checked ? Theme.colors.primary : Theme.colors.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        HoverHandler {
            id: hover
        }

        MouseArea {
            id: press
            anchors.fill: parent
            onClicked: button.clicked()
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
            property bool dragging: false

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: shot.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ikigai:shot"
            color: "transparent"

            readonly property string frozen: shot.frozen ? "file://" + shot.dir + "/" + modelData.name + ".png" : ""
            readonly property bool wholeScreen: shot.mode === "screen" && hover.hovered
            readonly property rect shown: wholeScreen ? Qt.rect(0, 0, content.width, content.height) : selection
            readonly property bool selecting: shown.width > 0 && shown.height > 0

            function setMode(mode) {
                shot.mode = mode;
                selection = Qt.rect(0, 0, 0, 0);
            }

            Item {
                id: content
                anchors.fill: parent
                focus: true
                opacity: shot.frozen && !shot.closing ? 1 : 0

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
                    const mode = shot.modes.find(m => m.key === event.key);
                    if (mode) {
                        window.setMode(mode.id);
                        event.accepted = true;
                        return;
                    }
                    switch (event.key) {
                    case Qt.Key_Escape: shot.cancel(); break;
                    case Qt.Key_Tab: {
                        const i = shot.actions.findIndex(a => a.id === shot.action);
                        shot.action = shot.actions[(i + 1) % shot.actions.length].id;
                        break;
                    }
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (window.selecting)
                            shot.commit(window, window.shown);
                        break;
                    default: return;
                    }
                    event.accepted = true;
                }

                HoverHandler {
                    id: hover
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
                    x: window.shown.x
                    y: window.shown.y
                    width: window.shown.width
                    height: window.shown.height
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
                    readonly property int weight: shot.flashing ? 4 : 2
                    x: crop.x - weight
                    y: crop.y - weight
                    width: crop.width + 2 * weight
                    height: crop.height + 2 * weight
                    visible: window.selecting
                    color: "transparent"
                    border.width: weight
                    border.color: shot.flashing ? Theme.colors.fg : Theme.colors.primary
                    radius: weight

                    Behavior on border.color {
                        ColorAnim {}
                    }
                }

                Rectangle {
                    visible: window.selecting && !window.wholeScreen
                    x: Math.min(crop.x + crop.width + 8, content.width - width - 8)
                    y: Math.min(crop.y + crop.height + 8, content.height - height - 8)
                    width: size.implicitWidth + 16
                    height: size.implicitHeight + 8
                    radius: height / 2
                    color: Theme.colors.surfaceContainerHigh

                    Text {
                        id: size
                        anchors.centerIn: parent
                        text: Math.round(window.shown.width * window.screen.devicePixelRatio) + " × " + Math.round(window.shown.height * window.screen.devicePixelRatio)
                        color: Theme.colors.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: !shot.frozen ? Qt.BlankCursor : shot.mode === "screen" ? Qt.PointingHandCursor : Qt.CrossCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            shot.cancel();
                            return;
                        }
                        if (shot.mode === "screen" || !shot.frozen)
                            return;
                        window.dragging = true;
                        window.anchor = Qt.point(mouse.x, mouse.y);
                        window.selection = Qt.rect(mouse.x, mouse.y, 0, 0);
                    }
                    onPositionChanged: mouse => {
                        if (!window.dragging)
                            return;
                        const x = Math.max(0, Math.min(mouse.x, content.width));
                        const y = Math.max(0, Math.min(mouse.y, content.height));
                        window.selection = Qt.rect(Math.min(x, window.anchor.x), Math.min(y, window.anchor.y), Math.abs(x - window.anchor.x), Math.abs(y - window.anchor.y));
                    }
                    onReleased: mouse => {
                        if (mouse.button !== Qt.LeftButton)
                            return;
                        window.dragging = false;
                        if (window.selecting)
                            shot.commit(window, window.shown);
                        else
                            window.selection = Qt.rect(0, 0, 0, 0);
                    }
                }

                // What to capture, and what to do with it.
                Rectangle {
                    id: pill
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(24 * Config.scale)
                    width: groups.implicitWidth + 12
                    height: groups.implicitHeight + 12
                    radius: height / 2
                    color: Theme.colors.surfaceContainer
                    border.width: 1
                    border.color: Theme.colors.outlineVariant
                    opacity: window.dragging || shot.flashing ? 0.25 : 1

                    Behavior on opacity {
                        Anim { effects: true; fast: true }
                    }

                    Row {
                        id: groups
                        anchors.centerIn: parent
                        spacing: 8

                        Row {
                            spacing: 2

                            Repeater {
                                model: shot.modes

                                PillButton {
                                    required property var modelData
                                    icon: modelData.icon
                                    label: modelData.label
                                    checked: shot.mode === modelData.id
                                    onClicked: window.setMode(modelData.id)
                                }
                            }
                        }

                        Rectangle {
                            width: 1
                            height: Math.round(18 * Config.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.colors.outlineVariant
                        }

                        Row {
                            spacing: 2

                            Repeater {
                                model: shot.actions

                                PillButton {
                                    required property var modelData
                                    icon: modelData.icon
                                    label: modelData.label
                                    checked: shot.action === modelData.id
                                    onClicked: shot.action = modelData.id
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
