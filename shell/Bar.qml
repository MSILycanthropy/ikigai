import Quickshell
import QtQuick

PanelWindow {
    id: bar

    property bool shown: true
    readonly property bool wanted: !Config.autohide || hover.hovered || taskbar.menuOpen

    anchors {
        left: true
        top: true
        bottom: true
    }
    // Stay full width while any content is on screen, so the strip only appears after the slide.
    implicitWidth: content.x > -Theme.barWidth ? Theme.barWidth : 2
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Config.autohide ? 0 : Theme.barWidth
    color: "transparent"

    // Reveal at once; hide after a grace period so grazing the edge doesn't flicker.
    Component.onCompleted: shown = wanted
    onWantedChanged: {
        if (wanted)
            shown = true;
        else
            hideTimer.restart();
    }

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
            width: Theme.barWidth
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
                anchors.fill: parent
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
                id: taskbar
                anchors {
                    top: parent.top
                    topMargin: 4
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Clock {
                anchors {
                    bottom: parent.bottom
                    bottomMargin: 8
                    horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
