//@ pragma IconTheme Cosmic
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    Switcher {}
    Shot {}
    Lock {}

    IpcHandler {
        target: "osd"

        function brightness(direction: string): void {
            Osd.brightness(direction);
        }
    }

    IpcHandler {
        target: "sidebar"

        function toggle(): void {
            Notifs.sidebarOpen = !Notifs.sidebarOpen;
        }
    }
}
