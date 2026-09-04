pragma Singleton
import Quickshell
import Quickshell.Services.Notifications

// The notification server. Live ones become toasts; every one is copied into a session
// history for the sidebar. Do-not-disturb skips the toast for all but critical urgency.
Singleton {
    id: root

    property var toasts: []
    property var history: []
    property int unread: 0
    property bool sidebarOpen: false
    readonly property bool dnd: Config.dnd
    readonly property int defaultTimeout: 5000

    NotificationServer {
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => root.receive(n)
    }

    function receive(n) {
        console.info("notification", n.appName, JSON.stringify(n.summary), "unread", unread + 1);
        n.tracked = true;
        n.closed.connect(() => root.forget(n));
        history = [snapshot(n), ...history].slice(0, 50);
        unread += 1;
        if (dnd && n.urgency !== NotificationUrgency.Critical)
            return;
        toasts = [...toasts, n];
    }

    function forget(n) {
        toasts = toasts.filter(t => t !== n);
    }

    function remove(entry) {
        history = history.filter(e => e !== entry);
    }

    function clear() {
        history = [];
    }

    onSidebarOpenChanged: if (sidebarOpen) unread = 0

    function snapshot(n) {
        return {
            id: n.id, appName: n.appName, icon: icon(n), summary: n.summary, body: n.body,
            image: n.image, urgency: n.urgency, time: new Date()
        };
    }

    // appIcon is a theme name, a path or a URL depending on the app; missing, the
    // desktop entry's icon.
    function icon(n) {
        if (n.appIcon.startsWith("/"))
            return "file://" + n.appIcon;
        if (n.appIcon.includes("://"))
            return n.appIcon;
        const name = n.appIcon || Apps.iconFor(n.desktopEntry || n.appName.toLowerCase());
        return Quickshell.iconPath(name, "dialog-information");
    }
}
