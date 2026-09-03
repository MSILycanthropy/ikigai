import QtQuick

NumberAnimation {
    property bool entering: true

    duration: Motion.standard
    easing.type: entering ? Motion.decelerate : Motion.accelerate
}
