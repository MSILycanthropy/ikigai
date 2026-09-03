import QtQuick

// A Phosphor glyph by name, coloured like text; `fill` switches to the filled weight.
Text {
    property string name: "question"
    property int size: 16
    property bool fill: false

    text: Icons.glyph(name)
    color: Theme.colors.fg
    font.family: fill ? Theme.iconFillFont : Theme.iconFont
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
