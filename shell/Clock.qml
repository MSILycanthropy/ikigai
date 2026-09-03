import Quickshell
import QtQuick

Column {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        anchors.right: parent.right
        text: clock.date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
        color: Theme.colors.fg
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
    }

    Text {
        anchors.right: parent.right
        text: clock.date.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
        color: Theme.colors.muted
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
    }
}
