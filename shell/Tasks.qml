pragma Singleton
import Quickshell
import QtQuick

// The two rail groups: pinned apps in order, with running unpinned apps appended to the top.
Singleton {
    id: root

    property var running: []
    readonly property var top: layout([...Config.pinned.top, ...running.filter(a => !pinnedAnywhere(a))])
    readonly property var bottom: layout([...Config.pinned.bottom])

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

    function pinnedAnywhere(appId) {
        return Config.pinned.top.includes(appId) || Config.pinned.bottom.includes(appId);
    }

    function layout(ids) {
        const windows = Bridge.windows;
        const apps = DesktopEntries.applications.values;
        return ids.map(appId => ({
            appId: appId,
            entry: Apps.entryFor(appId),
            pinned: pinnedAnywhere(appId),
            windows: windows.filter(w => w.appId === appId)
        }));
    }
}
