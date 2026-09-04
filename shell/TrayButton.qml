import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

// One tray item: click activates, right-click asks for its menu, middle-click is the
// secondary action, the wheel scrolls it.
BarButton {
    id: button

    required property var modelData
    readonly property SystemTrayItem item: modelData

    signal menuRequested(Item at)

    Image {
        anchors.centerIn: parent
        width: Theme.iconSize
        height: Theme.iconSize
        source: button.item.icon
        sourceSize: Qt.size(64, 64)
        fillMode: Image.PreserveAspectFit
        opacity: button.item.status === Status.Passive ? 0.6 : 1
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => {
            if (event.button === Qt.RightButton || (event.button === Qt.LeftButton && button.item.onlyMenu))
                button.menuRequested(button);
            else if (event.button === Qt.MiddleButton)
                button.item.secondaryActivate();
            else
                button.item.activate();
        }
    }

    WheelHandler {
        onWheel: event => button.item.scroll(event.angleDelta.y > 0 ? -1 : 1, false)
    }
}
