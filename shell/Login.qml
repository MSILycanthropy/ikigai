import Quickshell
import Quickshell.Services.Greetd
import QtQuick

// The greeter's card: the last user preselected, session pills, user switching and
// power. Enter authenticates through greetd; launching quits, and cosmic-comp with it.
AuthCard {
    id: login

    readonly property int lastUserIndex: Math.max(0, Accounts.users.findIndex(u => u.name === Users.lastUser))
    readonly property int lastSessionIndex: Math.max(0, Users.sessions.findIndex(s => s.id === Users.lastSession))
    property int userIndex: lastUserIndex
    property int sessionIndex: lastSessionIndex
    readonly property var session: Users.sessions[sessionIndex]

    user: Accounts.users[userIndex] || null

    onSubmit: password => {
        if (!session) {
            reject("No session to start");
            return;
        }
        pending = password;
        Greetd.createSession(user.name);
    }

    property string pending: ""

    function nextUser() {
        userIndex = (userIndex + 1) % Accounts.users.length;
        clear();
    }

    function power(action) {
        Quickshell.execDetached(["systemctl", action]);
    }

    Connections {
        target: Greetd

        function onAuthMessage(msg, error, responseRequired, echoResponse) {
            if (responseRequired)
                Greetd.respond(login.pending);
            else if (error)
                login.message = msg;
        }

        function onAuthFailure(msg) {
            login.pending = "";
            login.reject(/AUTH_ERR/.test(msg) ? "Wrong password" : (msg || "Authentication failed"));
        }

        // Quickshell 0.3.1 cancels the session after a failure, which greetd has already
        // dropped; that complaint arrives once we are idle again and is not worth showing.
        function onError(msg) {
            if (login.busy)
                login.reject(msg);
        }

        function onReadyToLaunch() {
            login.pending = "";
            Users.remember(login.user.name, login.session.id);
            const env = ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + login.session.id];
            if (login.session.desktopNames)
                env.push("XDG_CURRENT_DESKTOP=" + login.session.desktopNames);
            console.info("launch", login.user.name, login.session.id);
            Greetd.launch([login.session.exec], env, true);
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        visible: Users.sessions.length > 1

        Repeater {
            model: Users.sessions

            Rectangle {
                required property var modelData
                required property int index
                readonly property bool selected: index === login.sessionIndex

                width: label.width + 24
                height: Math.round(28 * Config.scale)
                radius: height / 2
                color: selected ? Theme.colors.primaryContainer : Theme.colors.surfaceContainerHigh

                Behavior on color {
                    ColorAnim {}
                }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.name
                    color: selected ? Theme.colors.primaryContainerFg : Theme.colors.fgVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.95
                }

                StateLayer {
                    radius: parent.radius
                    hovered: pillHover.hovered
                }

                HoverHandler {
                    id: pillHover
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: login.sessionIndex = index
                }
            }
        }
    }

    Item {
        width: parent.width
        height: powerRow.height

        BarButton {
            anchors.left: parent.left
            visible: Accounts.users.length > 1
            onClicked: login.nextUser()

            Glyph {
                anchors.centerIn: parent
                name: "users"
                size: 18
                color: Theme.colors.fgVariant
            }
        }

        Row {
            id: powerRow
            anchors.right: parent.right
            spacing: 4

            Repeater {
                model: [
                    { icon: "bed", action: "suspend" },
                    { icon: "arrow-clockwise", action: "reboot" },
                    { icon: "power", action: "poweroff" }
                ]

                BarButton {
                    required property var modelData
                    onClicked: login.power(modelData.action)

                    Glyph {
                        anchors.centerIn: parent
                        name: modelData.icon
                        size: 18
                        color: Theme.colors.fgVariant
                    }
                }
            }
        }
    }
}
