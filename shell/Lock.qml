import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick

// The lock screen: ext-session-lock surfaces on every screen with the wallpaper, and the
// auth card on the first checking the password through PAM. Locked and unlocked over
// IPC by the session launcher, which relays logind's Lock and Unlock signals.
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
