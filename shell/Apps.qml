pragma Singleton
import Quickshell

Singleton {
    // The last segment of a reverse-DNS id, lowercased: "com.valvesoftware.Steam" → "steam".
    // Flatpak exports an app under its own id while the window keeps the native app_id, so
    // the Flathub Steam's entry and its "steam" window meet here, and Discord's the same.
    function short(id) {
        return id.slice(id.lastIndexOf(".") + 1).toLowerCase();
    }

    function entryFor(appId) {
        const id = appId.toLowerCase();
        const apps = DesktopEntries.applications.values;
        return apps.find(e => e.id.toLowerCase() === id) || apps.find(e => e.startupClass.toLowerCase() === id) || apps.find(e => short(e.id) === id) || null;
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
        "steam": "steam-logo",
        "com.system76.CosmicSettings": "gear",
        // Not installed by Ikigai, but Phosphor has their marks: by the native app_id, and
        // by the last segment of the Flatpak id where that is not the name.
        "chromium": "google-chrome-logo",
        "google-chrome": "google-chrome-logo",
        "chrome": "google-chrome-logo",
        "slack": "slack-logo",
        "spotify": "spotify-logo",
        "com.spotify.Client": "spotify-logo",
        "org.telegram.desktop": "telegram-logo",
        "whatsapp": "whatsapp-logo",
        "element": "matrix-logo",
        "figma-linux": "figma-logo",
        "dropbox": "dropbox-logo",
        "com.dropbox.Client": "dropbox-logo",
        "github-desktop": "github-logo",
        "twitch": "twitch-logo",
        "tidal-hifi": "tidal-logo"
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
        if (known[appId] || known[short(appId)])
            return known[appId] || known[short(appId)];
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
