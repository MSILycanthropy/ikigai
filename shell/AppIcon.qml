import QtQuick

// Theme PNG icons only come in fixed sizes; asking for 24 px gets the 16 px file stretched.
// Fetch a large source and let the scene graph scale it down with mipmaps instead.
Image {
    property int size: Theme.iconSize

    width: size
    height: size
    sourceSize: Qt.size(256, 256)
    fillMode: Image.PreserveAspectFit
    mipmap: true
}
