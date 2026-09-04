import Quickshell
import QtQuick

// One window in the switcher: icon and title over a preview slot. The slot shows the app
// icon until the bridge can capture windows.
Item {
    id: tile

    property var entry: null
    property bool selected: false

    signal clicked

    readonly property int inset: Math.round(8 * Config.scale)
    readonly property string icon: Quickshell.iconPath(Apps.iconFor(entry ? entry.appId : ""), "application-x-executable")

    height: header.height + inset * 3 + preview.height

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius + tile.inset
        color: tile.selected ? Theme.colors.surfaceContainerHigh : "transparent"
        border.width: 1
        border.color: tile.selected ? Theme.colors.primary : "transparent"

        Behavior on color {
            ColorAnimation { duration: Motion.fastEffects }
        }

        StateLayer {
            radius: parent.radius
            hovered: hover.hovered
        }
    }

    Item {
        id: header
        x: tile.inset
        y: tile.inset
        width: parent.width - 2 * tile.inset
        height: Math.round(20 * Config.scale)

        AppIcon {
            id: smallIcon
            anchors.verticalCenter: parent.verticalCenter
            size: 16
            source: tile.icon
        }

        Text {
            anchors {
                left: smallIcon.right
                leftMargin: 8
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            text: tile.entry ? tile.entry.title : ""
            elide: Text.ElideRight
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
        }
    }

    Rectangle {
        id: preview
        x: tile.inset
        y: header.y + header.height + tile.inset
        width: parent.width - 2 * tile.inset
        height: Math.round(width * 9 / 16)
        radius: Theme.radius
        color: Theme.colors.surfaceContainerLow

        AppIcon {
            anchors.centerIn: parent
            size: 48
            source: tile.icon
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        onClicked: tile.clicked()
    }
}
