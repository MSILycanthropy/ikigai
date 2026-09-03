import QtQuick

// An icon-font glyph (Nerd Font code point) that follows the theme like text does.
Text {
    property int size: 16

    color: Theme.colors.fg
    font.family: Theme.iconFont
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
