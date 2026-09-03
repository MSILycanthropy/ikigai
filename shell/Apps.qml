pragma Singleton
import Quickshell

Singleton {
    function entryFor(appId) {
        const id = appId.toLowerCase();
        const apps = DesktopEntries.applications.values;
        return apps.find(e => e.id.toLowerCase() === id) || apps.find(e => e.startupClass.toLowerCase() === id) || null;
    }

    function iconFor(appId) {
        const entry = entryFor(appId);
        return entry && entry.icon ? entry.icon : "application-x-executable";
    }

    function launch(entry) {
        const command = entry.runInTerminal ? ["ghostty", "-e", ...entry.command] : entry.command;
        spawn(command, entry.workingDirectory);
    }

    // Each app gets its own transient scope: a child left in the shell unit's cgroup dies
    // with it on restart, and app.slice is where desktops put apps.
    function spawn(command, workingDirectory) {
        const context = { command: ["systemd-run", "--user", "--quiet", "--collect", "--scope", "--slice=app", "--", ...command] };
        if (workingDirectory)
            context.workingDirectory = workingDirectory;
        Quickshell.execDetached(context);
    }
}
