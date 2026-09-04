import Quickshell
import QtQuick

// Stacked clock for a narrow rail: hours over minutes, date beneath. Click opens the
// sidebar; a badge counts notifications not yet seen there.
Item {
    implicitWidth: Theme.barWidth
    implicitHeight: column.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    StateLayer {
        hovered: hover.hovered
        active: Notifs.sidebarOpen
    }

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

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

    Rectangle {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: -14
            rightMargin: 0
        }
        width: Math.max(height, badge.implicitWidth + 8)
        height: Math.round(16 * Config.scale)
        radius: height / 2
        color: Theme.colors.primary
        visible: Notifs.unread > 0

        Text {
            id: badge
            anchors.centerIn: parent
            text: Notifs.unread > 99 ? "99+" : Notifs.unread
            color: Theme.colors.primaryFg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 4
            font.bold: true
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Notifs.sidebarOpen = !Notifs.sidebarOpen
    }
}
