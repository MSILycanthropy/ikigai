import QtQuick

// A month at a glance: weeks starting Monday, today in the accent, arrows to browse.
Column {
    id: calendar

    property date shown: new Date()
    readonly property date today: new Date()
    readonly property int cell: Math.round(36 * Config.scale)
    readonly property int offset: (shown.getDay() + 6) % 7
    readonly property int days: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()

    spacing: Math.round(6 * Config.scale)

    function shift(months) {
        const d = new Date(shown);
        d.setDate(1);
        d.setMonth(d.getMonth() + months);
        shown = d;
    }

    function isToday(day) {
        return day === today.getDate() && shown.getMonth() === today.getMonth() && shown.getFullYear() === today.getFullYear();
    }

    Item {
        width: parent.width
        height: Theme.barWidth - 8

        BarButton {
            anchors.left: parent.left
            onClicked: calendar.shift(-1)

            Glyph {
                anchors.centerIn: parent
                name: "caret-left"
                size: 16
                color: Theme.colors.fgVariant
            }
        }

        Text {
            anchors.centerIn: parent
            text: Qt.formatDate(calendar.shown, "MMMM yyyy")
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Medium
        }

        BarButton {
            anchors.right: parent.right
            onClicked: calendar.shift(1)

            Glyph {
                anchors.centerIn: parent
                name: "caret-right"
                size: 16
                color: Theme.colors.fgVariant
            }
        }
    }

    Grid {
        columns: 7
        columnSpacing: (parent.width - 7 * calendar.cell) / 6

        Repeater {
            model: 7

            Text {
                required property int index
                width: calendar.cell
                text: Qt.locale().dayName(index + 1, Locale.NarrowFormat)
                color: Theme.colors.outline
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 3
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Grid {
        columns: 7
        columnSpacing: (parent.width - 7 * calendar.cell) / 6
        rowSpacing: 2

        Repeater {
            model: 42

            Item {
                required property int index
                readonly property int day: index - calendar.offset + 1
                readonly property bool inMonth: day >= 1 && day <= calendar.days
                readonly property bool today: inMonth && calendar.isToday(day)

                width: calendar.cell
                height: calendar.cell

                Rectangle {
                    anchors.centerIn: parent
                    width: calendar.cell - 6
                    height: width
                    radius: width / 2
                    color: Theme.colors.primary
                    visible: parent.today
                }

                Text {
                    anchors.centerIn: parent
                    text: parent.inMonth ? parent.day : ""
                    color: parent.today ? Theme.colors.primaryFg : Theme.colors.fg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 1
                    font.weight: parent.today ? Font.Bold : Font.Normal
                }
            }
        }
    }
}
