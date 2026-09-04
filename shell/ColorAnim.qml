import QtQuick

// Anim's effects curve for colours, so fills and outlines settle the way opacity does.
ColorAnimation {
    property bool fast: false

    duration: fast ? Motion.fastEffects : Motion.defaultEffects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: fast ? Motion.fastEffectsCurve : Motion.defaultEffectsCurve
}
