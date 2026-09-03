pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/ikigai"
    readonly property int barWidth: Math.round(40 * Config.scale)
    readonly property int iconSize: Math.round(20 * Config.scale)
    readonly property real fontSize: theme.font.size * Config.scale
    // The frame around the desktop and how blobs melt into it (caelestia-shell's defaults).
    readonly property int border: Math.round(10 * Config.scale)
    readonly property int rounding: Math.round(25 * Config.scale)
    readonly property int smoothing: Math.round(20 * Config.scale)
    readonly property int cardRadius: Math.round(28 * Config.scale)
    readonly property string fontFamily: theme.font.family
    readonly property string iconFont: theme.font.icons
    readonly property string iconFillFont: theme.font.iconsFill

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
                property string icons: "Phosphor"
                property string iconsFill: "Phosphor-Fill"
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
