pragma Singleton
import Quickshell

// The primary screen: where the lock, polkit and welcome cards, the switcher and toasts
// go, and where the sidebar opens from the command line. Wayland has no primary output,
// so it is `monitor` in shell.json while that output is connected, else the first one the
// compositor announced (which is whichever cable it enumerated first, not the one you
// look at).
Singleton {
    readonly property ShellScreen primary: {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === Config.monitor)
                return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }
}
