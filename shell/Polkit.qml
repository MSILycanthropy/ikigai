import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick

// The session's polkit agent, on the lock screen's card. Stock COSMIC had one inside
// cosmic-osd; without an agent a privilege prompt (Settings' Users page, a timezone
// change) fails with no dialog at all. polkit picks the identity to authenticate as,
// so the card names that account, which is not always the one logged in. Where polkit
// offers several admins its own pick stands; a chooser can come later.
Scope {
    id: scope

    readonly property var flow: agent.flow
    readonly property bool asking: flow !== null && !flow.isCompleted
    property var card: null

    readonly property var user: {
        const name = flow && flow.selectedIdentity ? flow.selectedIdentity.displayName : "";
        return Accounts.users.find(u => u.name === name) || { name: name, fullName: name, avatar: "" };
    }

    PolkitAgent {
        id: agent
    }

    Connections {
        target: scope.flow

        // polkit asks again after a wrong password, so the card recovers rather than closes.
        function onAuthenticationFailed() {
            if (scope.card)
                scope.card.reject(scope.flow.supplementaryMessage || "Authentication failed");
        }
    }

    LazyLoader {
        active: scope.asking

        PanelWindow {
            screen: Quickshell.screens[0]

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ikigai:polkit"
            color: Qt.alpha("black", 0.5)

            MouseArea {
                anchors.fill: parent
                onClicked: scope.flow.cancelAuthenticationRequest()
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: scope.flow.cancelAuthenticationRequest()

                AuthCard {
                    anchors.centerIn: parent
                    user: scope.user
                    subtitle: scope.flow ? scope.flow.message : ""
                    Component.onCompleted: scope.card = this
                    onSubmit: password => scope.flow.submit(password)
                }
            }
        }
    }
}
