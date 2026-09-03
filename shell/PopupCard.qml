import QtQuick

// Card beside the rail: springs out of the rail edge while its content fades in. Sized
// by whoever fills it; the host leaves Motion.slack on the left for the gap to the rail.
// The body itself is drawn by Goo from this item's geometry.
Item {
    property bool shown: false
    default property alias content: body.data

    x: shown ? Motion.slack : Motion.slack - Motion.rise
    visible: body.opacity > 0

    Item {
        id: body
        anchors {
            fill: parent
            margins: 6
        }
        opacity: shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Motion.standard }
        }
    }

    Behavior on x {
        Slide {
            duration: Motion.slow
            easing.type: Motion.spring
            easing.overshoot: 1.4
        }
    }
}
