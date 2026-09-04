pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// What the on-screen display shows: the output level, the microphone's mute or the
// backlight, for a moment after each change. Brightness runs through brightnessctl
// here because nothing else reports it back.
Singleton {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property bool shown: false
    // The volume card shows the level itself.
    property bool suppressed: false
    // PipeWire reports the initial levels as changes; wait them out.
    property bool armed: false
    readonly property string icon: kind === "brightness" ? (value < 0.5 ? "sun-dim" : "sun")
        : kind === "mic" ? (muted ? "microphone-slash" : "microphone") : Audio.icon

    function show(kind) {
        if (!armed || (suppressed && kind === "volume"))
            return;
        root.kind = kind;
        if (kind === "volume") {
            value = Audio.volume;
            muted = Audio.muted;
        } else if (kind === "mic") {
            value = Audio.micMuted ? 0 : 1;
            muted = Audio.micMuted;
        }
        console.info("osd", kind, Math.round(value * 100), muted ? "muted" : "");
        shown = true;
        hide.restart();
    }

    function brightness(direction) {
        brightnessctl.command = ["brightnessctl", "-m", "set", direction === "up" ? "5%+" : "5%-"];
        brightnessctl.running = true;
    }

    Timer {
        id: hide
        interval: 1500
        onTriggered: root.shown = false
    }

    Timer {
        interval: 2000
        running: true
        onTriggered: root.armed = true
    }

    Process {
        id: brightnessctl
        stdout: StdioCollector {
            // device,class,current,percent,max
            onStreamFinished: {
                const fields = text.trim().split(",");
                if (fields.length < 4)
                    return;
                root.kind = "brightness";
                root.value = parseInt(fields[3]) / 100;
                root.muted = false;
                root.shown = true;
                hide.restart();
            }
        }
    }
}
