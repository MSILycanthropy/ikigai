import QtQuick

// Card body for a popup beside the rail: springs out of the rail edge while fading in.
// The popup window must be 2 * Motion.slack wider than the card: room on the left for
// the gap to the rail and on the right for the overshoot.
Rectangle {
    property bool shown: false

    width: parent.width - 2 * Motion.slack
    height: parent.height
    x: shown ? Motion.slack : Motion.slack - Motion.rise
    opacity: shown ? 1 : 0
    radius: Theme.radius
    color: Theme.colors.bg
    border.color: Theme.colors.border

    Behavior on x {
        Slide {
            duration: Motion.slow
            easing.type: Motion.spring
            easing.overshoot: 1.4
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: Motion.standard }
    }
}
