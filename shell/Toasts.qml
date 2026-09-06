import Quickshell
import QtQuick

// The toast stack: one sheet hanging from the frame's top border at the right, which Bar
// draws as a blob and masks for input. Rows fade in and shuffle up as others leave.
Column {
    id: toasts

    readonly property alias hovered: hover.hovered
    // Off on the other screens: an empty column takes no space, so Bar's blob and mask
    // collapse with it.
    property bool active: true

    spacing: 0

    add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.defaultEffects }
    }

    move: Transition {
        NumberAnimation { property: "y"; duration: Motion.defaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.defaultSpatialCurve }
    }

    HoverHandler {
        id: hover
    }

    Repeater {
        model: ScriptModel {
            values: toasts.active ? Notifs.toasts : []
        }

        Toast {}
    }
}
