import QtQuick

// Card beside the rail: springs out of the rail edge while fading in. Sized by whoever
// fills it; the host leaves Motion.slack on the left for the gap to the rail.
Rectangle {
    property bool shown: false
    default property alias content: body.data

    x: shown ? Motion.slack : Motion.slack - Motion.rise
    opacity: shown ? 1 : 0
    visible: opacity > 0
    radius: Theme.radius
    color: Theme.colors.bg
    border.color: Theme.colors.border

    Item {
        id: body
        anchors {
            fill: parent
            margins: 6
        }
    }

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
