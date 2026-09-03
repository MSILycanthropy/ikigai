import Quickshell
import QtQuick

PanelWindow {
    id: bar

    property bool shown: true
    readonly property bool wanted: !Config.autohide || hover.hovered

    anchors {
        left: true
        top: true
        bottom: true
    }
    // Wide enough for the rail and a card; stay so while any content is on screen, so the
    // strip only appears after the slide.
    implicitWidth: content.x > -Theme.barWidth ? Theme.barWidth + popouts.width : 2
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Config.autohide ? 0 : Theme.barWidth
    color: "transparent"

    // Input only on the rail and the open card; the rest of the window passes through.
    // The rail region stays at x 0 so the 2 px strip keeps hover while hidden.
    mask: Region {
        x: 0
        y: 0
        width: Theme.barWidth
        height: bar.height

        regions: [
            Region {
                x: content.x + Theme.barWidth
                y: popouts.card ? popouts.card.y : 0
                width: popouts.card ? popouts.card.x + popouts.card.width : 0
                height: popouts.card ? popouts.card.height : 0
            }
        ]
    }

    // Reveal at once; hide after a grace period so grazing the edge doesn't flicker.
    Component.onCompleted: shown = wanted
    onWantedChanged: {
        if (wanted)
            shown = true;
        else
            hideTimer.restart();
    }
    onShownChanged: if (!shown) popouts.close()

    Timer {
        id: hideTimer
        interval: 400
        onTriggered: bar.shown = bar.wanted
    }

    Item {
        anchors.fill: parent

        HoverHandler {
            id: hover
        }

        Item {
            id: content
            width: Theme.barWidth + popouts.width
            height: parent.height
            x: bar.shown ? 0 : -Theme.barWidth

            // Direction from the Behavior itself: property bindings on `shown` have no ordering guarantee.
            Behavior on x {
                id: slide
                Slide {
                    entering: slide.targetValue === 0
                }
            }

            Rectangle {
                id: rail
                width: Theme.barWidth
                height: parent.height
                color: Theme.colors.bg

                Rectangle {
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                    }
                    width: 1
                    color: Theme.colors.border
                }
            }

            Taskbar {
                anchors {
                    top: parent.top
                    topMargin: 4
                    horizontalCenter: rail.horizontalCenter
                }
                workspacesOpen: popouts.workspacesOpen
                onMenuRequested: (task, at) => popouts.openMenu(task, at)
                onWorkspacesRequested: at => popouts.toggleWorkspaces(at)
            }

            Clock {
                anchors {
                    bottom: parent.bottom
                    bottomMargin: 8
                    horizontalCenter: rail.horizontalCenter
                }
            }

            Popouts {
                id: popouts
                x: Theme.barWidth
                height: parent.height
                hovered: hover.hovered
            }
        }
    }
}
