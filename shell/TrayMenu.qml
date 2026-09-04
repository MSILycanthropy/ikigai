import Quickshell
import QtQuick

// A tray item's menu: its top-level entries with separators and check marks.
PopupCard {
    id: menu

    // `task` carries the tray item, as Popouts hands it over.
    readonly property var item: task

    implicitWidth: 240
    implicitHeight: rows.implicitHeight + 12

    QsMenuOpener {
        id: opener
        menu: menu.item ? menu.item.menu : null
    }

    Column {
        id: rows
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        Repeater {
            model: opener.children

            Item {
                id: row
                required property var modelData

                width: rows.width
                height: modelData.isSeparator ? 9 : 32

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    height: 1
                    color: Theme.colors.outlineVariant
                    visible: row.modelData.isSeparator
                }

                StateLayer {
                    hovered: rowHover.hovered && row.modelData.enabled
                    visible: !row.modelData.isSeparator
                }

                Glyph {
                    anchors {
                        left: parent.left
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    name: "check"
                    size: 14
                    color: Theme.colors.primary
                    visible: row.modelData.checkState === Qt.Checked
                }

                Text {
                    anchors.fill: parent
                    leftPadding: 30
                    verticalAlignment: Text.AlignVCenter
                    text: row.modelData.text
                    visible: !row.modelData.isSeparator
                    color: row.modelData.enabled ? Theme.colors.fg : Theme.colors.outline
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    elide: Text.ElideRight
                }

                HoverHandler {
                    id: rowHover
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !row.modelData.isSeparator && row.modelData.enabled
                    onClicked: {
                        menu.done();
                        row.modelData.triggered();
                    }
                }
            }
        }
    }
}
