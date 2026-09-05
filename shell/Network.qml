pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// NetworkManager through nmcli: the wired and Wi-Fi state, the networks in range, and
// connect, disconnect, forget and the radio switch. `nmcli monitor` streams every change
// and each line refreshes the state. Quickshell has no NetworkManager service; this
// singleton is the boundary a D-Bus backend could replace without touching the cards.
//
// Secrets never go on a command line: a new secured network gets a profile without a
// key, the password waits in a file under the runtime dir, and `connection up` reads it
// from there. NetworkManager keeps the key in the profile after a success; a failure
// removes the profile again so the network asks next time rather than staying broken.
// The profile starts with autoconnect off, or NetworkManager tries it keyless the moment
// it exists and that attempt's failure would read as ours; success switches it on.
Singleton {
    id: root

    property bool wifiHardware: false
    property bool wifiEnabled: false
    property string connectivity: ""
    property bool wired: false
    property string wifiDevice: ""
    property string ssid: ""
    property int strength: 0
    // Networks in range: { ssid, strength, secure, active, saved }, active first, then by strength.
    property var networks: []
    property var saved: []
    property string pending: ""
    // The profile the pending connect created, deleted again if it fails.
    property string fresh: ""
    property string error: ""
    // The secured network the password window is open for.
    property string asking: ""
    // Authentication rounds of the pending connect: NetworkManager asks again after a
    // rejected key, and nmcli hands it the same file, so a third ask means a wrong password.
    property int authRounds: 0

    // The welcome card asks for the rail's network card; Bar answers.
    signal cardRequested

    readonly property bool online: connectivity === "full"
    readonly property bool connected: ssid !== "" || wired
    readonly property string icon: ssid !== "" ? wifiIcon(strength) : wired ? "network" : !wifiHardware ? "network-slash" : wifiEnabled ? "wifi-x" : "wifi-slash"
    readonly property string pskFile: Quickshell.env("XDG_RUNTIME_DIR") + "/ikigai-psk"

    function wifiIcon(level) {
        return level >= 66 ? "wifi-high" : level >= 33 ? "wifi-medium" : level > 0 ? "wifi-low" : "wifi-none";
    }

    function refresh() {
        state.running = true;
        list.running = true;
    }

    function scan() {
        rescan.running = true;
    }

    function connect(name, password) {
        pending = name;
        error = "";
        authRounds = 0;
        fresh = saved.includes(name) ? "" : name;
        const secure = networks.some(n => n.ssid === name && n.secure);
        if (fresh === "")
            act(["nmcli", "-w", "30", "connection", "up", "id", name]);
        else if (!secure)
            act(["nmcli", "-w", "30", "device", "wifi", "connect", name]);
        else {
            psk.setText("802-11-wireless-security.psk:" + password + "\n");
            act(["sh", "-c", 'nmcli connection add type wifi ifname "*" con-name "$0" ssid "$0" wifi-sec.key-mgmt wpa-psk connection.autoconnect no >/dev/null && nmcli -w 30 connection up id "$0" passwd-file "$1" >/dev/null && nmcli connection modify id "$0" connection.autoconnect yes; rc=$?; rm -f "$1"; exit $rc', name, pskFile]);
        }
    }

    function disconnect() {
        act(["nmcli", "device", "disconnect", wifiDevice]);
    }

    function forget(name) {
        act(["nmcli", "connection", "delete", "id", name]);
    }

    function setWifi(on) {
        act(["nmcli", "radio", "wifi", on ? "on" : "off"]);
    }

    function act(command) {
        console.info("network", command.slice(0, 4).join(" "));
        action.command = command;
        action.running = true;
    }

    // Deleting a fresh profile also aborts its activation, so the connect process ends.
    function failed() {
        if (pending === "")
            return;
        if (fresh !== "") {
            cleanup.command = ["nmcli", "connection", "delete", "id", fresh];
            cleanup.running = true;
        }
        error = "Couldn't connect";
        pending = "";
        fresh = "";
    }

    // "KEY:value" lines from `-m multiline`, one record per run of fields starting at `first`.
    function records(text, first) {
        const out = [];
        for (const line of text.split("\n")) {
            const i = line.indexOf(":");
            if (i < 0)
                continue;
            const key = line.slice(0, i), value = line.slice(i + 1);
            if (key === first)
                out.push({});
            if (out.length > 0)
                out[out.length - 1][key] = value;
        }
        return out;
    }

    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (root.pending !== "" && line.startsWith(root.wifiDevice + ": ")) {
                    const what = line.slice(root.wifiDevice.length + 2);
                    console.info("network", what);
                    if (what === "connection failed" || (what === "connecting (need authentication)" && ++root.authRounds >= 3))
                        root.failed();
                }
                settle.restart();
            }
        }
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: root.refresh()
    }

    Process {
        id: state
        command: ["sh", "-c", "nmcli -t -f STATE,CONNECTIVITY,WIFI,WIFI-HW general; echo ---; nmcli -t -m multiline -f DEVICE,TYPE,STATE,CONNECTION device; echo ---; nmcli -t -m multiline -f NAME,TYPE connection show"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const [general, devices, profiles] = text.split("---\n");
                const g = general.trim().split(":");
                root.connectivity = g[1] || "";
                root.wifiEnabled = g[2] === "enabled";
                root.wifiHardware = g[3] === "enabled";
                const devs = root.records(devices, "DEVICE");
                root.wired = devs.some(d => d.TYPE === "ethernet" && d.STATE === "connected");
                const wifi = devs.find(d => d.TYPE === "wifi" && d.STATE !== "unmanaged");
                root.wifiDevice = wifi ? wifi.DEVICE : "";
                root.saved = root.records(profiles, "NAME").filter(p => p.TYPE === "802-11-wireless").map(p => p.NAME);
            }
        }
    }

    Process {
        id: list
        command: ["nmcli", "-t", "-m", "multiline", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Set();
                const found = [];
                for (const r of root.records(text, "IN-USE")) {
                    if (r.SSID === "" || seen.has(r.SSID))
                        continue;
                    seen.add(r.SSID);
                    found.push({ ssid: r.SSID, strength: parseInt(r.SIGNAL) || 0, secure: r.SECURITY !== "", active: r["IN-USE"] === "*", saved: root.saved.includes(r.SSID) });
                }
                found.sort((a, b) => (b.active - a.active) || (b.strength - a.strength));
                root.networks = found;
                const active = found.find(n => n.active);
                root.ssid = active ? active.ssid : "";
                root.strength = active ? active.strength : 0;
                if (active && root.pending === active.ssid) {
                    root.pending = "";
                    root.error = "";
                }
            }
        }
    }

    Process {
        id: rescan
        command: ["sh", "-c", "nmcli device wifi rescan 2>/dev/null; sleep 2"]
        onExited: list.running = true
    }

    Process {
        id: action
        stderr: StdioCollector {
            id: actionErr
        }
        onExited: code => {
            if (code !== 0) {
                console.warn("network", code, actionErr.text.trim());
                root.failed();
            }
            root.refresh();
        }
    }

    Process {
        id: cleanup
        onExited: root.refresh()
    }

    FileView {
        id: psk
        path: root.pskFile
        blockWrites: true
        printErrors: false
    }
}
