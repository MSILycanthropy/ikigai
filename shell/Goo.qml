import QtQuick

// Background for the rail and whichever card is open, drawn as one gooey shape.
// Geometry comes in as item-space rectangles; see shaders/goo.frag.
ShaderEffect {
    property Item card: null
    property real cardOffset: 0

    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property vector4d rail: Qt.vector4d(0, 0, Theme.barWidth, height)
    readonly property vector4d railRadii: Qt.vector4d(Theme.radius, Theme.radius, 0, 0)
    readonly property vector4d cardBox: card ? Qt.vector4d(cardOffset + card.x, card.y, card.width, card.height) : Qt.vector4d(0, 0, 0, 0)
    readonly property real cardRadius: Theme.radius
    readonly property real smoothing: Theme.goo
    readonly property color fill: Theme.colors.bg
    readonly property color line: Theme.colors.border

    fragmentShader: Qt.resolvedUrl("shaders/goo.frag.qsb")
}
