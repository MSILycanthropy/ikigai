import Quickshell
import Quickshell.Services.Greetd
import QtQuick
import QtQuick.Effects

// The login card: the last user preselected with their avatar, a password field, session
// pills, then user switching and power. Enter authenticates through greetd; a failure
// shakes the card and shows PAM's message. Launching quits, and cosmic-comp with it.
Item {
    id: login

    readonly property int lastUserIndex: Math.max(0, Users.users.findIndex(u => u.name === Users.lastUser))
    readonly property int lastSessionIndex: Math.max(0, Users.sessions.findIndex(s => s.id === Users.lastSession))
    property int userIndex: lastUserIndex
    property int sessionIndex: lastSessionIndex
    readonly property var user: Users.users[userIndex]
    readonly property var session: Users.sessions[sessionIndex]
    property string message: ""
    property bool busy: false

    readonly property int pad: Math.round(28 * Config.scale)
    readonly property int fieldWidth: Math.round(280 * Config.scale)
    readonly property int avatarSize: Math.round(96 * Config.scale)

    implicitWidth: card.width + 48
    implicitHeight: card.height + 48

    function submit() {
        if (!user || !session || busy || password.text === "")
            return;
        busy = true;
        message = "";
        Greetd.createSession(user.name);
    }

    function nextUser() {
        userIndex = (userIndex + 1) % Users.users.length;
        password.text = "";
        message = "";
    }

    function power(action) {
        Quickshell.execDetached(["systemctl", action]);
    }

    Connections {
        target: Greetd

        function onAuthMessage(msg, error, responseRequired, echoResponse) {
            if (responseRequired)
                Greetd.respond(password.text);
            else if (error)
                login.message = msg;
        }

        function onAuthFailure(msg) {
            login.message = /AUTH_ERR/.test(msg) ? "Wrong password" : (msg || "Authentication failed");
            login.busy = false;
            password.text = "";
            shake.restart();
        }

        // Quickshell 0.3.1 cancels the session after a failure, which greetd has already
        // dropped; that complaint arrives once we are idle again and is not worth showing.
        function onError(msg) {
            if (!login.busy)
                return;
            login.message = msg;
            login.busy = false;
        }

        function onReadyToLaunch() {
            Users.remember(login.user.name, login.session.id);
            const env = ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + login.session.id];
            if (login.session.desktopNames)
                env.push("XDG_CURRENT_DESKTOP=" + login.session.desktopNames);
            console.info("launch", login.user.name, login.session.id);
            Greetd.launch([login.session.exec], env, true);
        }
    }

    SequentialAnimation {
        id: shake
        loops: 3
        NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -8; duration: 40 }
        NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 8; duration: 80 }
        NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: column.width + 2 * login.pad
        height: column.height + 2 * login.pad
        radius: Theme.cardRadius
        color: Theme.colors.surface
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.96
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha("black", 0.6)
        }

        property bool shown: false
        Component.onCompleted: shown = true

        Behavior on opacity {
            Anim { effects: true }
        }

        Behavior on scale {
            Anim {}
        }

        Column {
            id: column
            x: login.pad
            y: login.pad
            spacing: Math.round(16 * Config.scale)

            Item {
                id: avatar
                width: login.avatarSize
                height: login.avatarSize
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    source: login.user ? "file://" + login.user.avatar : ""
                    sourceSize: Qt.size(256, 256)
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: avatarImage
                    maskEnabled: true
                    maskSource: avatarMask
                    visible: avatarImage.status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.colors.primaryContainer
                    visible: avatarImage.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text: login.user ? login.user.fullName.charAt(0).toUpperCase() : ""
                        color: Theme.colors.primaryContainerFg
                        font.family: Theme.fontFamily
                        font.pixelSize: login.avatarSize * 0.45
                        font.weight: Font.Medium
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: login.user ? login.user.fullName : ""
                color: Theme.colors.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 1.5
                font.weight: Font.Medium
            }

            Rectangle {
                id: field
                width: login.fieldWidth
                height: Math.round(44 * Config.scale)
                radius: Theme.radius
                color: Theme.colors.surfaceContainerHigh
                border.width: 1
                border.color: password.activeFocus ? Theme.colors.primary : Theme.colors.outlineVariant
                opacity: login.busy ? 0.6 : 1

                Behavior on border.color {
                    ColorAnim {}
                }

                TextInput {
                    id: password
                    anchors {
                        left: parent.left
                        right: go.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 14
                    }
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: Theme.colors.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 1.1
                    focus: true
                    enabled: !login.busy
                    clip: true
                    Keys.onReturnPressed: login.submit()
                    Keys.onEnterPressed: login.submit()
                    Keys.onEscapePressed: { text = ""; login.message = ""; }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password"
                        color: Theme.colors.outline
                        font: password.font
                        visible: password.text === ""
                    }
                }

                BarButton {
                    id: go
                    anchors {
                        right: parent.right
                        rightMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    onClicked: login.submit()

                    Glyph {
                        anchors.centerIn: parent
                        name: "arrow-right"
                        size: 18
                        color: password.text === "" ? Theme.colors.outline : Theme.colors.primary
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: login.fieldWidth
                text: login.message
                visible: login.message !== ""
                color: Theme.colors.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
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
                width: login.fieldWidth
                height: powerRow.height

                BarButton {
                    anchors.left: parent.left
                    visible: Users.users.length > 1
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
                            { icon: "moon", action: "suspend" },
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
    }
}
