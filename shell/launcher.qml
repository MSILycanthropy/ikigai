//@ pragma IconTheme Cosmic
import Quickshell
import Quickshell.Io
import QtQuick

// The launcher is its own process: cosmic-comp only grants keyboard focus to a layer
// surface when it maps, and a mapped surface can't be hidden without killing the
// connection, so the window is created on open and the process exits on close.
// ikigai-launcher.service restarts it immediately, warm for the next open.
ShellRoot {
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (window.active)
                Qt.quit();
            else
                window.active = true;
        }
    }

    LazyLoader {
        id: window
        active: false

        Launcher {}
    }
}
