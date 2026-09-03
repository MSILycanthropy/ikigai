pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    property var running: []
    readonly property var items: layout([...Config.pinned], running, Bridge.windows, DesktopEntries.applications.values)

    Connections {
        target: Bridge
        function onWindowsChanged() {
            const live = [];
            for (const w of Bridge.windows)
                if (!live.includes(w.appId))
                    live.push(w.appId);
            root.running = [...root.running.filter(a => live.includes(a)), ...live.filter(a => !root.running.includes(a))];
        }
    }

    function layout(pinned, running, windows, apps) {
        const ids = [...pinned, ...running.filter(a => !pinned.includes(a))];
        return ids.map(appId => ({
            appId: appId,
            entry: Apps.entryFor(appId),
            pinned: pinned.includes(appId),
            windows: windows.filter(w => w.appId === appId)
        }));
    }
}
