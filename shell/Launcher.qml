import Quickshell
import Quickshell.Wayland
import QtQuick
import "Search.js" as Search

PanelWindow {
    id: launcher

    readonly property int rowHeight: 44
    readonly property var actions: [
        { id: "action:lock", name: "Lock", detail: "Lock the screen", glyph: "\uf023", command: ["loginctl", "lock-session"] },
        { id: "action:logout", name: "Log out", detail: "End the session", glyph: "\uf08b", command: ["pkill", "-TERM", "-x", "ikigai-session"] },
        { id: "action:restart", name: "Restart", detail: "Reboot the computer", glyph: "\uf021", command: ["systemctl", "reboot"] },
        { id: "action:shutdown", name: "Shut down", detail: "Power off the computer", glyph: "\uf011", command: ["systemctl", "poweroff"] }
    ]
    readonly property var items: [
        ...DesktopEntries.applications.values.map(entry => ({
            id: entry.id, name: entry.name, detail: entry.genericName || entry.comment, icon: entry.icon, entry: entry,
            terms: [entry.name, entry.genericName, ...entry.keywords, entry.comment].filter(Boolean).map(s => s.toLowerCase())
        })),
        ...actions.map(a => Object.assign({ terms: [a.name.toLowerCase(), a.detail.toLowerCase()] }, a))
    ]
    readonly property var results: Search.rank(query.text, items, 8)

    anchors.top: true
    margins.top: 120
    implicitWidth: 560
    implicitHeight: card.implicitHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "ikigai-launcher"

    readonly property var pinned: [...Config.pinned].map(Apps.entryFor).filter(Boolean)
    readonly property bool focused: card.Window.active

    Component.onCompleted: query.forceActiveFocus()
    onResultsChanged: list.currentIndex = 0
    onFocusedChanged: if (!focused) Qt.quit()

    function run(item) {
        if (item.entry)
            Apps.launch(item.entry);
        else
            Apps.spawn(item.command);
        Qt.quit();
    }

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: 56 + (query.text ? list.contentHeight + 8 : quick.height + 12) + footer.height
        radius: Theme.radius
        color: Theme.colors.bg
        border.color: Theme.colors.border

        TextInput {
            id: query
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 16
            }
            height: 24
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize + 2
            clip: true

            Keys.onEscapePressed: Qt.quit()
            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onReturnPressed: if (list.currentItem) launcher.run(list.currentItem.item)

            Text {
                anchors.fill: parent
                visible: !query.text
                text: "Search apps and actions"
                color: Theme.colors.muted
                font: query.font
            }
        }

        ListView {
            id: list
            anchors {
                left: parent.left
                right: parent.right
                top: query.bottom
                margins: 8
                topMargin: 12
            }
            height: contentHeight
            interactive: false
            highlightMoveDuration: Motion.quick
            highlightResizeDuration: 0

            visible: !!query.text

            model: ScriptModel {
                values: launcher.results
                objectProp: "id"
            }

            highlight: Rectangle {
                radius: Theme.radius - 2
                color: Theme.colors.surface
            }

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property var item: modelData

                width: list.width
                height: launcher.rowHeight

                Item {
                    id: icon
                    anchors {
                        left: parent.left
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    width: Theme.iconSize
                    height: Theme.iconSize

                    AppIcon {
                        visible: !row.item.glyph
                        source: Quickshell.iconPath(row.item.icon || "application-x-executable", "application-x-executable")
                    }

                    Glyph {
                        anchors.fill: parent
                        visible: !!row.item.glyph
                        text: row.item.glyph || ""
                        size: 18
                    }
                }

                Column {
                    anchors {
                        left: icon.right
                        leftMargin: 12
                        right: parent.right
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: row.item.name
                        color: Theme.colors.fg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        visible: !!row.item.detail
                        text: row.item.detail || ""
                        color: Theme.colors.muted
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 2
                    }
                }

                HoverHandler {
                    onHoveredChanged: if (hovered) list.currentIndex = row.index
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: launcher.run(row.item)
                }
            }
        }

        Row {
            id: quick
            anchors {
                left: parent.left
                top: query.bottom
                leftMargin: 12
                topMargin: 12
            }
            visible: !query.text
            spacing: 4

            Repeater {
                model: launcher.pinned

                BarButton {
                    required property var modelData

                    onClicked: launcher.run({ entry: modelData })

                    AppIcon {
                        anchors.centerIn: parent
                        source: Quickshell.iconPath(modelData.icon || "application-x-executable", "application-x-executable")
                    }
                }
            }
        }

        Item {
            id: footer
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 44

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 8
                }
                height: 1
                color: Theme.colors.border
            }

            Row {
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                spacing: 2

                Repeater {
                    model: launcher.actions

                    BarButton {
                        required property var modelData

                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: launcher.run(modelData)

                        Glyph {
                            anchors.centerIn: parent
                            text: modelData.glyph
                            color: Theme.colors.muted
                        }
                    }
                }
            }
        }
    }
}
