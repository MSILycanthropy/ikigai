import QtQuick

// The volume card: the output's name, mute, a slider.
PopupCard {
    id: card

    implicitWidth: 260
    implicitHeight: column.implicitHeight + 24

    Column {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 6
        }
        spacing: 8

        Text {
            width: parent.width
            text: Audio.sinkName
            color: Theme.colors.fgVariant
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            spacing: 8

            BarButton {
                id: mute
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Audio.toggleMute()

                Glyph {
                    anchors.centerIn: parent
                    name: Audio.icon
                    size: Theme.iconSize
                    color: Audio.muted ? Theme.colors.fgVariant : Theme.colors.fg
                }
            }

            Item {
                id: slider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - mute.width - level.width - 2 * parent.spacing
                height: 24

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.colors.surfaceContainerHighest

                    Rectangle {
                        width: track.width * Audio.volume
                        height: parent.height
                        radius: parent.radius
                        color: Audio.muted ? Theme.colors.outline : Theme.colors.primary
                    }
                }

                Rectangle {
                    x: track.width * Audio.volume - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: Audio.muted ? Theme.colors.outline : Theme.colors.primary
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: mouse => Audio.setVolume(mouse.x / width)
                    onPositionChanged: mouse => { if (pressed) Audio.setVolume(mouse.x / width); }
                }

                WheelHandler {
                    onWheel: event => Audio.step(event.angleDelta.y > 0 ? 0.05 : -0.05)
                }
            }

            Text {
                id: level
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                text: Math.round(Audio.volume * 100)
                color: Theme.colors.fg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
