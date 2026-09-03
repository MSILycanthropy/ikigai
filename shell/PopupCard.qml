import QtQuick

// Card body for a popup above the bar: springs up out of the bar edge while fading in.
// The popup window must be 2 * Motion.slack taller than the card: room below for the
// gap to the bar and above for the overshoot.
Rectangle {
    property bool shown: false

    width: parent.width
    height: parent.height - 2 * Motion.slack
    y: shown ? Motion.slack : Motion.slack + Motion.rise
    opacity: shown ? 1 : 0
    radius: Theme.radius
    color: Theme.colors.bg
    border.color: Theme.colors.border

    Behavior on y {
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
