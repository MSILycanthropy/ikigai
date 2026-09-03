import QtQuick

// Card beside the rail: grows out of the rail edge while its content fades in, and
// shrinks back into it. Subclasses set implicitWidth/Height; the body is drawn by the
// blob layer in Bar from this item's geometry.
Item {
    property bool shown: false
    default property alias content: body.data

    width: shown ? implicitWidth : 0
    height: shown ? implicitHeight : 0
    visible: width > 0
    clip: true

    Item {
        id: body
        x: 6
        y: 6
        width: parent.implicitWidth - 12
        height: parent.implicitHeight - 12
        opacity: shown ? 1 : 0

        Behavior on opacity {
            Anim { effects: true }
        }
    }

    Behavior on width {
        Anim {}
    }

    Behavior on height {
        Anim {}
    }
}
