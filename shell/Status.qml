import Quickshell.Services.SystemTray
import QtQuick

// Status items above the clock: tray icons, the battery when there is one, then the
// output volume (scroll to adjust, click for the card).
Column {
    id: status

    property bool batteryOpen: false
    property bool volumeOpen: false

    signal batteryRequested(Item at)
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
        id: battery
        visible: Power.present
        checked: status.batteryOpen
        onClicked: status.batteryRequested(battery)

        Glyph {
            anchors.centerIn: parent
            name: Power.icon
            size: Theme.iconSize
            color: Power.low ? Theme.colors.error : Theme.colors.fg
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
