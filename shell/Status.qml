import QtQuick

// Status items above the clock: the output volume, scroll to adjust, click for the card.
Column {
    id: status

    property bool volumeOpen: false

    signal volumeRequested(Item at)

    spacing: 4

    BarButton {
        id: volume
        checked: status.volumeOpen
        onClicked: status.volumeRequested(volume)

        Glyph {
            anchors.centerIn: parent
            name: Audio.icon
            size: Theme.iconSize
            color: Audio.muted ? Theme.colors.fgVariant : Theme.colors.fg
        }

        WheelHandler {
            onWheel: event => Audio.step(event.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }
}
