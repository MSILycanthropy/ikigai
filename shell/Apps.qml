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

    // Rail glyph for an app: the user's override, then apps Ikigai ships, then the
    // desktop entry's category, then a generic window.
    readonly property var known: ({
        "com.mitchellh.ghostty": "brand:ghostty",
        "zen": "brand:zen",
        "dev.zed.Zed": "brand:zed",
        "com.github.th-ch.youtube-music": "youtube-logo",
        "discord": "discord-logo",
        "com.system76.CosmicSettings": "gear"
    })
    readonly property var categories: ({
        "TerminalEmulator": "terminal-window",
        "WebBrowser": "browser",
        "IDE": "code",
        "Development": "code",
        "TextEditor": "note-pencil",
        "Music": "music-notes",
        "Audio": "music-notes",
        "Player": "music-notes",
        "Video": "film-strip",
        "InstantMessaging": "chats",
        "Chat": "chats",
        "Network": "chats",
        "Settings": "gear",
        "FileManager": "folder",
        "Game": "game-controller",
        "Graphics": "image",
        "Office": "file-text",
        "System": "cpu",
        "Utility": "wrench"
    })

    function glyphFor(appId) {
        if (Config.icons[appId])
            return Config.icons[appId];
        if (known[appId])
            return known[appId];
        const entry = entryFor(appId);
        if (entry)
            for (const category of entry.categories)
                if (categories[category])
                    return categories[category];
        return "app-window";
    }

    function launch(entry) {
        const command = entry.runInTerminal ? ["ghostty", "-e", ...entry.command] : entry.command;
        spawn(command, entry.workingDirectory);
    }

    // Each app gets its own transient scope: a child left in the shell unit's cgroup dies
    // with it on restart, and app.slice is where desktops put apps.
    function spawn(command, workingDirectory) {
        console.info("spawn", command.join(" "));
        const context = { command: ["systemd-run", "--user", "--quiet", "--collect", "--scope", "--slice=app", "--", ...command] };
        if (workingDirectory)
            context.workingDirectory = workingDirectory;
        Quickshell.execDetached(context);
    }
}
