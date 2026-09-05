import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// The password window for a new secured network, in the polkit card's shape: the rail's
// popout has no keyboard focus, an Overlay layer with exclusive focus does. Opens while
// Network.asking names a network; Enter or Connect submits, a failure shows why and
// keeps the field, Escape or a click outside gives up.
Scope {
    id: scope

    readonly property bool busy: Network.pending !== "" && Network.pending === Network.asking

    function close() {
        Network.asking = "";
    }

    Connections {
        target: Network

        function onSsidChanged() {
            if (Network.ssid !== "" && Network.ssid === Network.asking)
                scope.close();
        }
    }

    LazyLoader {
        active: Network.asking !== ""

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
            WlrLayershell.namespace: "ikigai:wifi"
            color: Qt.alpha("black", 0.5)

            MouseArea {
                anchors.fill: parent
                onClicked: scope.close()
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: scope.close()

                Rectangle {
                    id: card

                    readonly property int pad: Math.round(28 * Config.scale)
                    readonly property int fieldWidth: Math.round(300 * Config.scale)

                    anchors.centerIn: parent
                    width: column.width + 2 * pad
                    height: column.height + 2 * pad
                    radius: Theme.cardRadius
                    color: Theme.colors.surface
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        blurMax: 15
                        shadowColor: Qt.alpha("black", 0.6)
                    }

                    MouseArea {
                        anchors.fill: parent
                    }

                    function submit() {
                        if (scope.busy || password.text === "")
                            return;
                        Network.connect(Network.asking, password.text);
                    }

                    Column {
                        id: column
                        x: card.pad
                        y: card.pad
                        spacing: Math.round(16 * Config.scale)

                        Column {
                            width: card.fieldWidth
                            spacing: 4

                            Text {
                                text: "Connect to " + Network.asking
                                width: parent.width
                                color: Theme.colors.fg
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize + 3
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "This network needs a password."
                                color: Theme.colors.fgVariant
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize
                            }
                        }

                        Rectangle {
                            width: card.fieldWidth
                            height: Math.round(44 * Config.scale)
                            radius: Theme.radius
                            color: Theme.colors.surfaceContainerHigh
                            border.width: 1
                            border.color: password.activeFocus ? Theme.colors.primary : Theme.colors.outlineVariant
                            opacity: scope.busy ? 0.6 : 1

                            Behavior on border.color {
                                ColorAnim {}
                            }

                            TextInput {
                                id: password
                                anchors {
                                    left: parent.left
                                    right: reveal.left
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 14
                                }
                                echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "•"
                                color: Theme.colors.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 1.1
                                focus: true
                                enabled: !scope.busy
                                clip: true
                                Keys.onReturnPressed: card.submit()
                                Keys.onEnterPressed: card.submit()
                                Component.onCompleted: forceActiveFocus()

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Password"
                                    color: Theme.colors.outline
                                    font: password.font
                                    visible: password.text === ""
                                }
                            }

                            BarButton {
                                id: reveal
                                anchors {
                                    right: parent.right
                                    rightMargin: 6
                                    verticalCenter: parent.verticalCenter
                                }
                                onClicked: checked = !checked

                                Glyph {
                                    anchors.centerIn: parent
                                    name: reveal.checked ? "eye-slash" : "eye"
                                    size: 18
                                    color: Theme.colors.fgVariant
                                }
                            }
                        }

                        Text {
                            width: card.fieldWidth
                            text: scope.busy ? "Connecting…" : Network.error
                            visible: text !== ""
                            color: scope.busy ? Theme.colors.fgVariant : Theme.colors.error
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                        }

                        Row {
                            anchors.right: parent.right
                            spacing: Math.round(10 * Config.scale)

                            Pill {
                                label: "Cancel"
                                onClicked: scope.close()
                            }

                            Pill {
                                primary: true
                                label: "Connect"
                                enabled: !scope.busy && password.text !== ""
                                onClicked: card.submit()
                            }
                        }
                    }
                }
            }
        }
    }
}
