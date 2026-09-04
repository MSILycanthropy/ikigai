import Quickshell.Services.SystemTray
import QtQuick

// Status items above the clock: tray icons, then the output volume (scroll to adjust,
// click for the card).
Column {
    id: status

    property bool volumeOpen: false

    signal volumeRequested(Item at)
    signal trayMenuRequested(var item, Item at)

    spacing: 4

    Repeater {
        model: SystemTray.items

        TrayButton {
            onMenuRequested: at => status.trayMenuRequested(item, at)
        }
    }

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
