import Quickshell
import QtQuick

// Stacked clock for a narrow rail: hours over minutes, date beneath.
Column {
    spacing: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(clock.date, "HH")
        color: Theme.colors.fg
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.bold: true
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(clock.date, "mm")
        color: Theme.colors.fg
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.bold: true
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        topPadding: 4
        text: Qt.formatDate(clock.date, "d MMM")
        color: Theme.colors.fgVariant
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 3
    }
}
