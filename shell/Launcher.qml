import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import Ikigai.Blobs

// The launcher's drop, on the focused screen: the frame's top border swells, a droplet
// stretches out of it on a neck, snaps free, falls and lands in the centre as the card,
// wobbling. Closing runs it backwards, the card lifting back into the border. One blob
// group draws the lot, so the droplet, the neck and the border are one liquid.
//
// Vicinae is the card's content: its window, chrome transparent and the card's size
// (config/vicinae/settings.json), opens as the card lands and sits over it on the
// overlay layer. Vicinae hides itself on Escape, on a launch or on focus loss and has
// no hook for it, so while it is up `vicinae state open` is polled and the card lifts
// when it says closed. `ikigai-shell launcher open|close|toggle`, Super's binding.
Scope {
    id: launcher

    property bool open: false
    // 0 in the border, 1 landed; the spatial curve overshoots past 1 for the bounce.
    property real progress: 0
    readonly property bool active: open || progress > 0.001
    // Vicinae's window is up inside the card.
    property bool vicinae: false
    // When to open Vicinae after the drop starts: its window maps in about 100 ms and
    // fades in over a tick, so this puts it on the card as the card settles.
    readonly property int reveal: 300

    function toggle() {
        open = !open;
    }

    onOpenChanged: {
        console.info("launcher", open ? "open" : "close");
        progress = open ? 1 : 0;
        if (open) {
            revealTimer.restart();
        } else {
            revealTimer.stop();
            if (vicinae) {
                vicinae = false;
                vicinaeClose.running = true;
            }
        }
    }

    Timer {
        id: revealTimer
        interval: launcher.reveal
        onTriggered: vicinaeOpen.running = true
    }

    Process {
        id: vicinaeOpen
        command: ["vicinae", "open"]
        onExited: (code, status) => {
            if (!launcher.open)
                return;
            if (code === 0) {
                launcher.vicinae = true;
            } else {
                console.warn("launcher: vicinae open failed", code);
                launcher.open = false;
            }
        }
    }

    Process {
        id: vicinaeClose
        command: ["vicinae", "close"]
    }

    // Vicinae closed on its own: lift the card.
    Timer {
        interval: 100
        repeat: true
        running: launcher.vicinae
        onTriggered: if (!vicinaeState.running) vicinaeState.running = true
    }

    Process {
        id: vicinaeState
        command: ["vicinae", "state", "open"]
        onExited: (code, status) => {
            if (code !== 0 && launcher.vicinae) {
                console.info("launcher: vicinae closed");
                launcher.vicinae = false;
                launcher.open = false;
            }
        }
    }

    // The drop gathers slowly, falls fast and overshoots into its wobble. Lifting back
    // is the same curve a little quicker: the card gathers itself, shoots up and
    // overshoots into the border (progress past 0 clamps, so it just sits).
    readonly property list<real> dropCurve: [0.55, 0, 0.45, 1.15, 1, 1]

    // Keyed off the value the Behavior was handed, not `open`: the write to `progress`
    // happens inside open's change handler, before bindings on `open` have caught up,
    // so reading `open` here gave every drop the lift's timing and every lift the drop's.
    Behavior on progress {
        id: motion
        Anim {
            duration: motion.targetValue > 0 ? 500 : 400
            easing.bezierCurve: launcher.dropCurve
        }
    }

    IpcHandler {
        target: "launcher"

        function open(): void { launcher.open = true; }
        function close(): void { launcher.open = false; }
        function toggle(): void { launcher.toggle(); }
    }

    // Mapped at rest: creating the surface on open cost the first 150 ms of the drop, the
    // whole neck. Idle it draws nothing and takes no input. The focused screen, which is
    // where Vicinae puts its window.
    PanelWindow {
        id: window
        screen: Screens.focused

        // Vicinae's window size (launcher_window.size in config/vicinae/settings.json).
        readonly property int cardWidth: 770
        readonly property int cardHeight: 480
        // Oversize above the edge so nothing of the reservoir's top ever shows.
        readonly property int over: 60
        readonly property real p: launcher.progress
        readonly property real landY: Math.round((height - cardHeight) / 2)
        // Two stages: to `emerge` the droplet slides out of the border and hangs `hang`
        // below it on its neck, on the curve's slow start; after it, the fast section
        // takes it down to the centre, growing into the card, and past 1 into the bounce.
        readonly property real emerge: 0.3
        readonly property real hang: Theme.border + Math.round(44 * Config.scale)

        function clamp(v) { return Math.max(0, Math.min(1, v)); }
        // A window onto [from, to] of the progress, 0..1 inside, clamped outside.
        function phase(from, to) { return clamp((p - from) / (to - from)); }

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        exclusionMode: ExclusionMode.Ignore
        // Below Vicinae's overlay-layer window, so clicks on the card reach it.
        WlrLayershell.layer: WlrLayer.Top
        // Keys during the drop (Escape); Vicinae takes them once it is up.
        WlrLayershell.keyboardFocus: launcher.open && !launcher.vicinae ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "ikigai:launcher"
        color: "transparent"

        // The whole screen while open, so a click beside the card closes it; nothing
        // while it lifts away, so the desktop is back at once.
        mask: Region {
            x: 0
            y: 0
            width: launcher.open ? window.width : 0
            height: launcher.open ? window.height : 0
        }

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    launcher.open = false;
                    event.accepted = true;
                }
            }

            MouseArea {
                id: outside
                anchors.fill: parent
                onClicked: mouse => {
                    if (!drop.contains(drop.mapFromItem(outside, mouse.x, mouse.y)))
                        launcher.open = false;
                }
            }

            Item {
                anchors.fill: parent
                visible: launcher.active
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    // Deeper than the rail's: the card is the surface colour, and so is
                    // a terminal underneath it.
                    blurMax: 32
                    shadowColor: Qt.alpha("black", 0.8)
                }

                BlobGroup {
                    id: blobs
                    color: Theme.colors.surface
                    // Wider than the rail's so the neck stays liquid longer before it snaps.
                    smoothing: Theme.smoothing * 2
                }

                // The reservoir: the top border, bulging as the drop gathers and again
                // as it is taken back, flat once the droplet has gone.
                BlobRect {
                    group: blobs
                    readonly property real bulge: Math.sin(Math.PI * window.phase(0, 0.4)) * Math.round(26 * Config.scale)
                    readonly property real spread: window.cardWidth * (0.45 + 0.35 * window.phase(0, 0.2))
                    x: (window.width - spread) / 2
                    y: -window.over
                    implicitWidth: spread
                    implicitHeight: window.over + Theme.border + bulge
                    radius: Theme.cardRadius
                    deformScale: 0.15 / 10000
                }

                // The neck: hangs from the border to the droplet's top, thinning to
                // nothing early in the fall, where the smoothing lets it snap.
                BlobRect {
                    group: blobs
                    readonly property real thickness: window.cardWidth * 0.18 * Math.pow(1 - window.phase(window.emerge, 0.65), 1.6)
                    x: (window.width - thickness) / 2
                    y: 0
                    implicitWidth: thickness
                    implicitHeight: Math.max(0, drop.y + Theme.cardRadius)
                    radius: Theme.cardRadius
                    deformScale: 0.15 / 10000
                }

                // The droplet, growing into the card as it falls. The heavier deform
                // squashes it on landing.
                BlobRect {
                    id: drop
                    group: blobs
                    readonly property real grow: 0.45 + 0.55 * window.phase(window.emerge, 0.9)
                    readonly property real startY: -window.cardHeight * 0.45 - Theme.border
                    x: (window.width - implicitWidth) / 2
                    y: window.p < window.emerge
                        ? startY + (window.hang - startY) * (window.p / window.emerge)
                        : window.hang + (window.landY - window.hang) * ((window.p - window.emerge) / (1 - window.emerge))
                    implicitWidth: window.cardWidth * grow
                    implicitHeight: window.cardHeight * grow
                    radius: Theme.cardRadius
                    deformScale: 0.3 / 10000
                }
            }
        }
    }
}
