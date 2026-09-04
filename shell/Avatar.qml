import QtQuick
import QtQuick.Effects

// A user's picture in a circle, or their initial on the accent when there is none.
Item {
    id: avatar

    property var user: null
    property int size: Math.round(96 * Config.scale)

    width: size
    height: size

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }

    Image {
        id: image
        anchors.fill: parent
        source: avatar.user ? "file://" + avatar.user.avatar : ""
        sourceSize: Qt.size(256, 256)
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        maskEnabled: true
        maskSource: mask
        visible: image.status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.colors.primaryContainer
        visible: image.status !== Image.Ready

        Text {
            anchors.centerIn: parent
            text: avatar.user ? avatar.user.fullName.charAt(0).toUpperCase() : ""
            color: Theme.colors.primaryContainerFg
            font.family: Theme.fontFamily
            font.pixelSize: avatar.size * 0.45
            font.weight: Font.Medium
        }
    }
}
