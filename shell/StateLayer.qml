import QtQuick

// Interaction tint over a control, in its rounded shape: faint on hover, stronger while
// pressed or active. The button itself scales on press; this only paints.
Rectangle {
    property bool hovered: false
    property bool pressed: false
    property bool active: false

    anchors.fill: parent
    radius: Theme.radius
    color: Theme.colors.fg
    opacity: pressed ? 0.14 : active ? 0.12 : hovered ? 0.08 : 0

    Behavior on opacity {
        Anim { effects: true; fast: true }
    }
}
