import Quickshell
import Quickshell.Wayland
import QtQuick

// The frame window is anchored to every edge, so it can't reserve space itself: four
// 1 px windows hold the exclusive zones for it (caelestia-shell does the same).
Scope {
    id: root

    required property ShellScreen screen
    property int left: Theme.border

    component Zone: PanelWindow {
        screen: root.screen
        exclusiveZone: Theme.border
        mask: Region {}
        color: "transparent"
        implicitWidth: 1
        implicitHeight: 1
        WlrLayershell.namespace: "ikigai:exclusion"
    }

    Zone {
        anchors.left: true
        exclusiveZone: root.left
    }

    Zone {
        anchors.top: true
    }

    Zone {
        anchors.right: true
    }

    Zone {
        anchors.bottom: true
    }
}
