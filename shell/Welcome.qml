import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// The first-login card: keys, the rail, where settings live. Shown once per user, a
// moment after the shell starts, while ~/.local/state/ikigai/welcomed is missing; closing
// writes it. `ikigai-shell welcome open` brings it back. A box with no connectivity gets
// a button to Settings' Wi-Fi page, until the rail has its own network item.
Scope {
    id: scope

    property bool open: false
    property bool online: true

    readonly property var keys: [
        ["Super", "Vicinae: apps, files, clipboard; type log out or power off"],
        ["Super+W", "task view: workspaces and their windows"],
        ["Alt+Tab", "window switcher, hold and cycle"],
        ["Super+Return", "terminal"],
        ["Super+L", "lock"],
        ["Print", "screenshot picker"],
        ["Super+Shift+/", "every binding"],
    ]

    function close() {
        open = false;
        marker.setText(new Date().toISOString() + "\n");
    }

    function wifi() {
        Apps.spawn(["cosmic-settings", "wireless"]);
        close();
    }

    IpcHandler {
        target: "welcome"

        function open(): void {
            scope.open = true;
        }
    }

    FileView {
        id: marker
        path: Theme.stateDir + "/welcomed"
        printErrors: false
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                delay.start();
        }
    }

    // Let the wallpaper and the rail land first.
    Timer {
        id: delay
        interval: 1500
        onTriggered: scope.open = true
    }

    Process {
        command: ["nmcli", "-g", "CONNECTIVITY", "general"]
        running: scope.open
        stdout: StdioCollector {
            onStreamFinished: scope.online = text.trim() === "full"
        }
    }

    component Section: Row {
        id: section

        property string icon
        property string title
        default property alias body: bodySlot.data

        width: parent.width
        spacing: Math.round(14 * Config.scale)

        Glyph {
            name: section.icon
            size: Math.round(22 * Config.scale)
            color: Theme.colors.primary
        }

        Column {
            id: bodySlot
            width: parent.width - parent.spacing - Math.round(22 * Config.scale)
            spacing: Math.round(6 * Config.scale)

            Text {
                text: section.title
                color: Theme.colors.fg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize + 1
                font.weight: Font.Medium
            }
        }
    }

    component Body: Text {
        width: parent.width
        color: Theme.colors.fgVariant
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        wrapMode: Text.Wrap
    }

    component Pill: Rectangle {
        id: pill

        property string label
        property bool primary: false

        signal clicked

        width: pillText.width + Math.round(28 * Config.scale)
        height: Math.round(36 * Config.scale)
        radius: height / 2
        color: primary ? Theme.colors.primary : Theme.colors.surfaceContainerHigh

        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.primary ? Theme.colors.primaryFg : Theme.colors.primary
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Medium
        }

        StateLayer {
            radius: parent.radius
            hovered: pillHover.hovered
            pressed: pillPress.pressed
        }

        HoverHandler {
            id: pillHover
        }

        MouseArea {
            id: pillPress
            anchors.fill: parent
            onClicked: pill.clicked()
        }
    }

    LazyLoader {
        active: scope.open

        PanelWindow {
            screen: Quickshell.screens[0]

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ikigai:welcome"
            color: Qt.alpha("black", 0.5)

            MouseArea {
                anchors.fill: parent
                onClicked: scope.close()
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: scope.close()

                Rectangle {
                    id: card

                    readonly property int pad: Math.round(32 * Config.scale)

                    anchors.centerIn: parent
                    width: column.width + 2 * pad
                    height: column.height + 2 * pad
                    radius: Theme.cardRadius
                    color: Theme.colors.surface
                    opacity: shown ? 1 : 0
                    scale: shown ? 1 : 0.96
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        blurMax: 15
                        shadowColor: Qt.alpha("black", 0.6)
                    }

                    property bool shown: false
                    Component.onCompleted: shown = true

                    Behavior on opacity {
                        Anim { effects: true }
                    }

                    Behavior on scale {
                        Anim {}
                    }

                    MouseArea {
                        anchors.fill: parent
                    }

                    Column {
                        id: column
                        x: card.pad
                        y: card.pad
                        width: Math.round(520 * Config.scale)
                        spacing: Math.round(22 * Config.scale)

                        Column {
                            width: parent.width
                            spacing: Math.round(4 * Config.scale)

                            Text {
                                text: "Welcome to Ikigai"
                                color: Theme.colors.fg
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize * 1.8
                                font.weight: Font.Medium
                            }

                            Body {
                                text: "Three things worth knowing. The rest is in the cheatsheet."
                            }
                        }

                        Section {
                            icon: "keyboard"
                            title: "Keys"

                            Column {
                                width: parent.width
                                spacing: Math.round(4 * Config.scale)

                                Repeater {
                                    model: scope.keys

                                    Row {
                                        required property var modelData

                                        readonly property int chordWidth: Math.round(120 * Config.scale)

                                        width: parent.width
                                        spacing: Math.round(12 * Config.scale)

                                        Text {
                                            width: parent.chordWidth
                                            text: parent.modelData[0]
                                            color: Theme.colors.primary
                                            font.family: Theme.fontFamily
                                            font.pointSize: Theme.fontSize
                                            font.weight: Font.Medium
                                        }

                                        Body {
                                            width: parent.width - parent.chordWidth - parent.spacing
                                            text: parent.modelData[1]
                                        }
                                    }
                                }
                            }
                        }

                        Section {
                            icon: "sidebar-simple"
                            title: "The rail"

                            Body {
                                text: "Hover the left edge. Pinned apps at the top, right-click one to pin or unpin. Below them the tray, the volume and the clock, which opens notifications and the calendar."
                            }
                        }

                        Section {
                            icon: "gear"
                            title: "Settings"

                            Body {
                                text: "Type Settings into Vicinae for displays, wallpaper, keyboard and users. The rail's own options are in ~/.config/ikigai/shell.json."
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            spacing: Math.round(10 * Config.scale)

                            Pill {
                                visible: !scope.online
                                label: "Connect to Wi-Fi"
                                onClicked: scope.wifi()
                            }

                            Pill {
                                primary: true
                                label: "Got it"
                                onClicked: scope.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
