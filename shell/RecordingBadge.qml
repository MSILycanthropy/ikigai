import QtQuick

// A red dot and the elapsed time while a recording runs; click to stop. Takes no room
// otherwise.
Item {
    id: badge

    implicitWidth: Theme.barWidth
    implicitHeight: Recorder.recording ? column.implicitHeight : 0
    visible: Recorder.recording

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(10 * Config.scale)
            height: width
            radius: width / 2
            color: Theme.colors.error

            SequentialAnimation on opacity {
                running: Recorder.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Recorder.elapsed
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 3
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Recorder.stop()
    }
}
