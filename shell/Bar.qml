import Quickshell
import QtQuick

PanelWindow {
    id: bar

    property bool shown: true
    readonly property bool wanted: !Config.autohide || hover.hovered || taskbar.menuOpen

    anchors {
        left: true
        right: true
        bottom: true
    }
    // Stay full height while any content is on screen, so the strip only appears after the slide.
    implicitHeight: content.y < Theme.barHeight ? Theme.barHeight : 2
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Config.autohide ? 0 : Theme.barHeight
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
            width: parent.width
            height: Theme.barHeight
            y: bar.shown ? 0 : Theme.barHeight

            // Direction from the Behavior itself: property bindings on `shown` have no ordering guarantee.
            Behavior on y {
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
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    height: 1
                    color: Theme.colors.border
                }
            }

            Taskbar {
                id: taskbar
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: Config.align === "left" ? parent.left : undefined
                    leftMargin: 4
                    horizontalCenter: Config.align === "left" ? undefined : parent.horizontalCenter
                }
            }

            Clock {
                anchors {
                    right: parent.right
                    rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
