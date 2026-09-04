pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool connected: false
    property var windows: []
    property var workspaces: []
    // Latest preview per window id: { path, width, height }.
    property var thumbs: ({})

    function activate(id) { send({ request: "activate", id: id }); }
    function close(id) { send({ request: "close", id: id }); }
    function minimize(id) { send({ request: "minimize", id: id }); }
    function moveToWorkspace(id, workspace) { send({ request: "move_to_workspace", id: id, workspace: workspace }); }
    function activateWorkspace(workspace) { send({ request: "activate_workspace", workspace: workspace }); }
    function capture(ids) { send({ request: "capture", ids: ids }); }

    function send(request) {
        console.info("bridge request", JSON.stringify(request));
        if (!link.item || !link.item.connected)
            return;
        link.item.write(JSON.stringify(request) + "\n");
        link.item.flush();
    }

    function handle(event) {
        switch (event.event) {
        case "snapshot":
            windows = event.toplevels.map(fromWire);
            workspaces = event.workspaces;
            break;
        case "toplevel": {
            const w = fromWire(event.toplevel);
            const known = windows.some(x => x.id === w.id);
            windows = known ? windows.map(x => x.id === w.id ? w : x) : [...windows, w];
            break;
        }
        case "closed":
            windows = windows.filter(x => x.id !== event.id);
            thumbs = Object.fromEntries(Object.entries(thumbs).filter(([id]) => id !== event.id));
            break;
        case "thumbnail":
            thumbs = Object.assign({}, thumbs, { [event.id]: { path: event.path, width: event.width, height: event.height } });
            break;
        case "workspaces":
            workspaces = event.workspaces;
            break;
        case "error":
            console.warn("bridge:", event.message);
        }
    }

    function fromWire(t) {
        return { id: t.id, appId: t.app_id, title: t.title, states: t.states, outputs: t.outputs, workspaces: t.workspaces, lastActive: t.last_active };
    }

    // A Socket can't reconnect once it has failed or dropped, so each retry gets a fresh one.
    Loader {
        id: link

        sourceComponent: Socket {
            path: Quickshell.env("XDG_RUNTIME_DIR") + "/ikigai-bridge.sock"
            connected: true
            parser: SplitParser {
                onRead: line => root.handle(JSON.parse(line))
            }
            onConnectedChanged: {
                root.connected = connected;
                if (!connected) {
                    root.windows = [];
                    root.thumbs = {};
                    retry.start();
                }
            }
            onError: retry.start()
        }
    }

    Timer {
        id: retry
        interval: 1000
        onTriggered: {
            link.active = false;
            link.active = true;
        }
    }
}
