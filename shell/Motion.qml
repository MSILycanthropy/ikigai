pragma Singleton
import QtQuick
import Quickshell

// Material 3 expressive motion, the same tokens caelestia-shell uses: spatial curves
// overshoot and are for movement and size, effects curves are for opacity and colour.
Singleton {
    readonly property int fastSpatial: 350
    readonly property int defaultSpatial: 500
    readonly property int slowSpatial: 650
    readonly property int fastEffects: 150
    readonly property int defaultEffects: 200
    readonly property int slowEffects: 300
    readonly property int standard: 300

    readonly property list<real> fastSpatialCurve: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property list<real> defaultSpatialCurve: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property list<real> slowSpatialCurve: [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property list<real> fastEffectsCurve: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property list<real> defaultEffectsCurve: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property list<real> slowEffectsCurve: [0.34, 0.88, 0.34, 1, 1, 1]
    readonly property list<real> standardCurve: [0.2, 0, 0, 1, 1, 1]

    // Pointer grace before the rail hides or a card closes.
    readonly property int grace: 400
}
