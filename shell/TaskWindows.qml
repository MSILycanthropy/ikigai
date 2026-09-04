import Quickshell
import QtQuick

// The windows of one app as preview tiles: click focuses, middle-click or the x closes.
// Captures are requested each time the card opens, so the previews are current.
PopupCard {
    id: card

    readonly property var windows: task ? Bridge.windows.filter(w => w.appId === task.appId) : []

    onWindowsChanged: if (shown && windows.length === 0) done()
    onShownChanged: refresh()
    onTaskChanged: refresh()

    function refresh() {
        if (shown && windows.length > 0)
            Bridge.capture(windows.map(w => w.id));
    }

    implicitWidth: Math.round(216 * Config.scale) + 12
    implicitHeight: tiles.implicitHeight + 12

    Column {
        id: tiles
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: 4

        Repeater {
            model: ScriptModel {
                values: card.windows
                objectProp: "id"
            }

            WindowTile {
                required property var modelData

                width: tiles.width
                entry: modelData
                selected: modelData.states.includes("activated")
                closable: true
                onClicked: {
                    card.done();
                    Bridge.activate(modelData.id);
                }
                onCloseRequested: Bridge.close(modelData.id)
            }
        }
    }
}
