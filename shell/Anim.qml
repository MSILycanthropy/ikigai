import QtQuick

// One animation type for the shell: spatial by default, `effects` for fades, `standard`
// for things that must not overshoot (a border that shrinks to its minimum).
NumberAnimation {
    property bool effects: false
    property bool standard: false
    property bool fast: false

    duration: standard ? Motion.standard : effects ? (fast ? Motion.fastEffects : Motion.defaultEffects) : (fast ? Motion.fastSpatial : Motion.defaultSpatial)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: standard ? Motion.standardCurve : effects ? (fast ? Motion.fastEffectsCurve : Motion.defaultEffectsCurve) : (fast ? Motion.fastSpatialCurve : Motion.defaultSpatialCurve)
}
