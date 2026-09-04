import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// Alt+Tab. cosmic-comp runs `ikigai-shell switcher next` on every Tab press while Alt is
// held; the overlay takes exclusive keyboard focus when it maps, so the Alt release lands
// here and commits. The list is frozen while open, most recent first, like Windows.
Scope {
    id: switcher

    property bool open: false
    property var order: []
    property int index: 0

    IpcHandler {
        target: "switcher"

        function next(): void { switcher.step(1); }
        function prev(): void { switcher.step(-1); }
    }

    function step(by) {
        if (!open) {
            const windows = Bridge.windows.map((w, i) => ({ w: w, i: i }));
            order = windows.sort((a, b) => b.w.lastActive - a.w.lastActive || a.i - b.i).map(x => x.w);
            if (order.length === 0)
                return;
            index = 0;
            open = true;
        }
        index = (index + by + order.length) % order.length;
    }

    // cosmic-comp hands focus back to the previously focused window when the overlay unmaps,
    // which would undo an activate sent before that; so unmap first, activate once it is gone.
    property string pending: ""

    function commit(i) {
        pending = open && order[i] ? order[i].id : "";
        open = false;
        if (pending)
            settle.restart();
    }

    Timer {
        id: settle
        interval: 80
        onTriggered: {
            Bridge.activate(switcher.pending);
            switcher.pending = "";
        }
    }

    function cancel() {
        open = false;
    }

    // Windows closed while the switcher is open drop out of the list.
    Connections {
        target: Bridge

        function onWindowsChanged() {
            if (!switcher.open)
                return;
            const live = switcher.order.filter(w => Bridge.windows.some(x => x.id === w.id));
            if (live.length === 0) {
                switcher.cancel();
            } else if (live.length !== switcher.order.length) {
                switcher.index = Math.min(switcher.index, live.length - 1);
                switcher.order = live;
            }
        }
    }

    LazyLoader {
        active: switcher.open

        PanelWindow {
            id: window

            readonly property int shadowRoom: 24
            readonly property int tileWidth: Math.round(216 * Config.scale)
            readonly property int gap: Math.round(8 * Config.scale)
            readonly property int pad: Math.round(16 * Config.scale)

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ikigai:switcher"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            implicitWidth: card.width + 2 * shadowRoom
            implicitHeight: card.height + 2 * shadowRoom

            Item {
                id: keys
                anchors.fill: parent
                focus: true

                readonly property bool active: Window.active
                property bool wasActive: false

                // Losing focus to something else (a launcher, a lock) abandons the switch.
                onActiveChanged: {
                    if (active)
                        wasActive = true;
                    else if (wasActive)
                        switcher.cancel();
                }

                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta)
                        switcher.commit(switcher.index);
                }
                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape: switcher.cancel(); break;
                    case Qt.Key_Left: switcher.step(-1); break;
                    case Qt.Key_Right: switcher.step(1); break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space: switcher.commit(switcher.index); break;
                    default: return;
                    }
                    event.accepted = true;
                }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: grid.width + 2 * window.pad
                height: grid.height + 2 * window.pad
                radius: Theme.cardRadius
                color: Theme.colors.surface
                opacity: 0
                scale: 0.96
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 15
                    shadowColor: Qt.alpha("black", 0.6)
                }

                Component.onCompleted: {
                    opacity = 1;
                    scale = 1;
                }

                Behavior on opacity {
                    Anim { effects: true }
                }

                Behavior on scale {
                    Anim {}
                }

                Grid {
                    id: grid
                    x: window.pad
                    y: window.pad
                    columns: Math.max(1, Math.floor((window.screen.width - 160) / (window.tileWidth + window.gap)))
                    spacing: window.gap

                    Repeater {
                        model: ScriptModel {
                            values: switcher.order
                            objectProp: "id"
                        }

                        SwitcherTile {
                            required property var modelData
                            required property int index

                            entry: modelData
                            selected: index === switcher.index
                            width: window.tileWidth
                            onClicked: switcher.commit(index)
                        }
                    }
                }
            }
        }
    }
}
