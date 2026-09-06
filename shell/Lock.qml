import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick

// The lock screen: ext-session-lock surfaces on every screen with the wallpaper, and the
// auth card on the first checking the password through PAM. Locked and unlocked over
// IPC by the session launcher, which relays logind's Lock and Unlock signals and holds
// suspend back until `locked` reports the compositor has the lock.
Scope {
    id: scope

    IpcHandler {
        target: "session"

        function lock(): void {
            console.info("lock");
            scope.engage();
        }

        function unlock(): void {
            console.info("unlock");
            lock.locked = false;
        }

        // True once the compositor has covered every screen; the launcher waits for
        // this before letting logind suspend.
        function locked(): bool {
            return lock.secure;
        }
    }

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER")

        onPamMessage: {
            if (responseRequired)
                respond(scope.pending);
        }

        onCompleted: result => {
            scope.pending = "";
            if (result === PamResult.Success) {
                lock.locked = false;
                if (scope.card)
                    scope.card.clear();
            } else if (scope.card) {
                scope.card.reject(result === PamResult.MaxTries ? "Too many attempts" : "Wrong password");
            }
        }

        onError: error => {
            scope.pending = "";
            if (scope.card)
                scope.card.reject("PAM error: " + PamError.toString(error));
        }
    }

    property string pending: ""
    property var card: null

    // cosmic-comp moves keyboard focus to a lock surface only while fixing up a focus
    // that became invalid; with nothing focused (an empty desktop) it never does, and
    // the card would need a click. So take focus with an exclusive layer first, lock,
    // then drop the layer: its death is what makes the compositor look again.
    function engage() {
        bait.active = true;
        engageTimer.restart();
    }

    Timer {
        id: engageTimer
        interval: 100
        onTriggered: {
            lock.locked = true;
            releaseTimer.restart();
        }
    }

    Timer {
        id: releaseTimer
        interval: 300
        onTriggered: bait.active = false
    }

    // logind's LockedHint outlives the shell. Set while the compositor holds the lock
    // and read at startup: once the lock client dies cosmic-comp keeps the screen blank,
    // so a restarted shell locks again instead of leaving the box unusable.
    readonly property string sessionPath: Quickshell.env("IKIGAI_SESSION_PATH")

    function setLockedHint(locked) {
        if (sessionPath)
            Quickshell.execDetached(["busctl", "--system", "call", "org.freedesktop.login1", sessionPath, "org.freedesktop.login1.Session", "SetLockedHint", "b", locked ? "true" : "false"]);
    }

    Process {
        command: ["busctl", "--system", "get-property", "org.freedesktop.login1", scope.sessionPath, "org.freedesktop.login1.Session", "LockedHint"]
        running: scope.sessionPath !== ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "b true")
                    scope.engage();
            }
        }
    }

    LazyLoader {
        id: bait

        PanelWindow {
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ikigai:lock-bait"
            mask: Region {}
        }
    }

    WlSessionLock {
        id: lock
        locked: false
        onSecureChanged: scope.setLockedHint(secure)

        WlSessionLockSurface {
            id: surface
            color: Theme.colors.surface

            Image {
                anchors.fill: parent
                source: "file:///usr/local/share/ikigai/theme/wallpaper.jpg"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Loader {
                anchors.centerIn: parent
                active: surface.screen === Quickshell.screens[0]
                focus: true

                sourceComponent: AuthCard {
                    user: Accounts.current
                    Component.onCompleted: scope.card = this
                    onSubmit: password => {
                        scope.pending = password;
                        pam.start();
                    }
                }
            }
        }
    }
}
