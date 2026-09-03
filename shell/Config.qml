pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/ikigai"

    property alias pinned: config.pinned
    property alias autohide: config.autohide
    property alias scale: config.scale

    function pin(appId) {
        config.pinned = [...config.pinned, appId];
        file.writeAdapter();
    }

    function unpin(appId) {
        config.pinned = [...config.pinned].filter(a => a !== appId);
        file.writeAdapter();
    }

    FileView {
        id: file
        path: root.configDir + "/shell.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: config

            property list<string> pinned: []
            property bool autohide: true
            property real scale: 1.0
        }
    }
}
