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
                property string surface: "#100e0d"
                property string surfaceContainerLow: "#161312"
                property string surfaceContainer: "#1c1918"
                property string surfaceContainerHigh: "#231f1d"
                property string surfaceContainerHighest: "#2a2523"
                property string fg: "#eee3e0"
                property string fgVariant: "#b2a9a7"
                property string outline: "#7c7472"
                property string outlineVariant: "#4d4645"
                property string primary: "#86adff"
                property string primaryFg: "#002c66"
                property string primaryContainer: "#6e9fff"
                property string primaryContainerFg: "#002150"
                property string error: "#ff716c"
                property string success: "#7fc581"
                property string warning: "#d4ab4f"
            }
        }
    }
}
