pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/ikigai"
    readonly property int barWidth: Math.round(40 * Config.scale)
    readonly property int iconSize: Math.round(20 * Config.scale)
    readonly property real fontSize: theme.font.size * Config.scale
    readonly property int goo: Math.round(14 * Config.scale)
    readonly property string fontFamily: theme.font.family
    readonly property string iconFont: theme.font.icons

    property alias radius: theme.radius
    property alias colors: theme.colors

    FileView {
        path: root.stateDir + "/shell-theme.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: theme

            property JsonObject font: JsonObject {
                property string family: "Noto Sans"
                property int size: 12
                property string icons: "JetBrainsMono Nerd Font"
            }
            property int radius: 8
            property JsonObject colors: JsonObject {
                property string bg: "#1a1b26"
                property string surface: "#24283b"
                property string border: "#414868"
                property string fg: "#c0caf5"
                property string muted: "#a9b1d6"
                property string accent: "#7aa2f7"
                property string red: "#f7768e"
                property string green: "#9ece6a"
                property string yellow: "#e0af68"
            }
        }
    }
}
