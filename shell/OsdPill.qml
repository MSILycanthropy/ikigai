import QtQuick

// The on-screen display: a pill out of the frame's bottom border with a glyph, a bar and
// the level. Bar draws it as a blob.
Item {
    id: pill

    implicitWidth: Math.round(220 * Config.scale)
    implicitHeight: Math.round(44 * Config.scale)
    opacity: Osd.shown ? 1 : 0

    Behavior on opacity {
        Anim { effects: true; fast: true }
    }

    Row {
        anchors.centerIn: parent
        spacing: Math.round(12 * Config.scale)

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            name: Osd.icon
            size: Theme.iconSize
            color: Osd.muted ? Theme.colors.fgVariant : Theme.colors.fg
        }

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(110 * Config.scale)
            height: 6
            radius: 3
            color: Theme.colors.surfaceContainerHighest

            Rectangle {
                width: track.width * Osd.value
                height: parent.height
                radius: parent.radius
                color: Osd.muted ? Theme.colors.outline : Theme.colors.primary

                Behavior on width {
                    Anim { fast: true }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(34 * Config.scale)
            text: Math.round(Osd.value * 100)
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            horizontalAlignment: Text.AlignRight
        }
    }
}
