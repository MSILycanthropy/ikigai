import QtQuick

// A square bar button: hover surface, optional checked state, content centred inside.
Item {
    id: button

    property bool checked: false
    default property alias content: slot.data

    signal clicked

    implicitWidth: Theme.barHeight - 8
    implicitHeight: Theme.barHeight - 8

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.colors.surface
        opacity: hover.hovered || button.checked ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Motion.quick }
        }
    }

    Item {
        id: slot
        anchors.centerIn: parent
        width: 18
        height: 18
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        onClicked: button.clicked()
    }
}
