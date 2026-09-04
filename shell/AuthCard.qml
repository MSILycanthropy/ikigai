import QtQuick
import QtQuick.Effects

// A card that asks one user for a password: avatar, name, the field, a message line,
// then whatever the host adds below. Enter or the arrow submits; `reject` shakes the
// card, clears the field and shows why.
Item {
    id: card

    property var user: null
    property bool busy: false
    property string message: ""
    property string subtitle: ""
    default property alias extra: extraSlot.data

    signal submit(string password)

    readonly property int pad: Math.round(28 * Config.scale)
    readonly property int fieldWidth: Math.round(280 * Config.scale)

    implicitWidth: body.width + 48
    implicitHeight: body.height + 48

    function reject(why) {
        message = why;
        busy = false;
        password.text = "";
        shake.restart();
    }

    function clear() {
        password.text = "";
        message = "";
    }

    // A Loader only routes focus once it has it itself; claim it outright so the field
    // types without a click on both the greeter and the lock surface.
    Component.onCompleted: password.forceActiveFocus()

    function trySubmit() {
        if (!user || busy || password.text === "")
            return;
        busy = true;
        message = "";
        submit(password.text);
    }

    SequentialAnimation {
        id: shake
        loops: 3
        NumberAnimation { target: body; property: "anchors.horizontalCenterOffset"; to: -8; duration: 40 }
        NumberAnimation { target: body; property: "anchors.horizontalCenterOffset"; to: 8; duration: 80 }
        NumberAnimation { target: body; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
    }

    Rectangle {
        id: body
        anchors.centerIn: parent
        width: column.width + 2 * card.pad
        height: column.height + 2 * card.pad
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
            x: card.pad
            y: card.pad
            spacing: Math.round(16 * Config.scale)

            Avatar {
                anchors.horizontalCenter: parent.horizontalCenter
                user: card.user
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.user ? card.user.fullName : ""
                color: Theme.colors.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 1.5
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: card.fieldWidth
                text: card.subtitle
                visible: card.subtitle !== ""
                color: Theme.colors.fgVariant
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Rectangle {
                width: card.fieldWidth
                height: Math.round(44 * Config.scale)
                radius: Theme.radius
                color: Theme.colors.surfaceContainerHigh
                border.width: 1
                border.color: password.activeFocus ? Theme.colors.primary : Theme.colors.outlineVariant
                opacity: card.busy ? 0.6 : 1

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
                    enabled: !card.busy
                    clip: true
                    Keys.onReturnPressed: card.trySubmit()
                    Keys.onEnterPressed: card.trySubmit()
                    Keys.onEscapePressed: card.clear()

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
                    onClicked: card.trySubmit()

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
                width: card.fieldWidth
                text: card.message
                visible: card.message !== ""
                color: Theme.colors.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Column {
                id: extraSlot
                width: card.fieldWidth
                spacing: Math.round(16 * Config.scale)
            }
        }
    }
}
