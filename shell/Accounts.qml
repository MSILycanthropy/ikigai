pragma Singleton
import Quickshell
import Quickshell.Io

// Local accounts from /etc/passwd inside login.defs's UID range, with the avatar
// cosmic-settings writes for AccountsService. The greeter lists them; the lock screen
// looks up the one logged in.
Singleton {
    id: root

    property var users: []
    readonly property var current: users.find(u => u.name === Quickshell.env("USER")) || null

    function uidRange() {
        const range = {};
        for (const key of ["UID_MIN", "UID_MAX"]) {
            const m = defs.text().match(new RegExp("^" + key + "\\s+(\\d+)", "m"));
            range[key] = m ? parseInt(m[1]) : (key === "UID_MIN" ? 1000 : 60000);
        }
        return range;
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
}
