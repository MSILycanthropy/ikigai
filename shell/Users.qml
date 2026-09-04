pragma Singleton
import Quickshell
import Quickshell.Io

// Who can log in and how: local accounts from /etc/passwd inside login.defs's UID range,
// sessions from /usr/share/wayland-sessions, and the last choice kept in the greeter
// user's home. Avatars are what cosmic-settings writes for AccountsService.
Singleton {
    id: root

    property var users: []
    property var sessions: []
    property alias lastUser: last.user
    property alias lastSession: last.session

    function remember(user, session) {
        last.user = user;
        last.session = session;
        lastFile.writeAdapter();
    }

    function uidRange() {
        const range = {};
        for (const key of ["UID_MIN", "UID_MAX"]) {
            const m = defs.text().match(new RegExp("^" + key + "\\s+(\\d+)", "m"));
            range[key] = m ? parseInt(m[1]) : (key === "UID_MIN" ? 1000 : 60000);
        }
        return range;
    }

    function parseSessions(out) {
        const byId = {};
        for (const line of out.split("\n")) {
            const m = line.match(/^.*\/([^/]+)\.desktop:(\w+)=(.*)$/);
            if (!m)
                continue;
            if (!byId[m[1]])
                byId[m[1]] = { id: m[1] };
            byId[m[1]][m[2]] = m[3];
        }
        return Object.values(byId)
            .filter(s => s.Exec)
            .map(s => ({ id: s.id, name: s.Name || s.id, exec: s.Exec, desktopNames: s.DesktopNames || "" }))
            .sort((a, b) => a.id === "ikigai" ? -1 : b.id === "ikigai" ? 1 : a.name.localeCompare(b.name));
    }

    FileView {
        id: defs
        path: "/etc/login.defs"
        blockLoading: true
    }

    FileView {
        path: "/etc/passwd"
        onLoaded: {
            const range = root.uidRange();
            root.users = text().split("\n")
                .map(l => l.split(":"))
                .filter(f => f.length >= 7 && f[2] >= range.UID_MIN && f[2] <= range.UID_MAX && !f[6].endsWith("nologin"))
                .map(f => ({ name: f[0], fullName: f[4].split(",")[0] || f[0], avatar: "/var/lib/AccountsService/icons/" + f[0] }));
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "grep -H -E '^(Name|Exec|DesktopNames)=' /usr/share/wayland-sessions/*.desktop"]
        stdout: StdioCollector {
            onStreamFinished: root.sessions = root.parseSessions(text)
        }
    }

    FileView {
        id: lastFile
        path: Quickshell.env("HOME") + "/last.json"

        JsonAdapter {
            id: last
            property string user: ""
            property string session: "ikigai"
        }
    }
}
