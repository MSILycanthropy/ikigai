pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property int quick: 120
    readonly property int standard: 200
    readonly property int slow: 320
    readonly property int rise: 28
    readonly property int slack: 6

    readonly property int decelerate: Easing.OutCubic
    readonly property int accelerate: Easing.InCubic
    readonly property int settle: Easing.InOutCubic
    readonly property int spring: Easing.OutBack
}
