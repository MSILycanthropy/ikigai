//@ pragma IconTheme Cosmic
import Quickshell
import Quickshell.Wayland
import QtQuick

// greetd's greeter, run by ikigai-greeter under cosmic-comp: the theme's wallpaper on
// every screen and the login card on the first.
ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: modelData === Quickshell.screens[0] ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "ikigai:greeter"
            color: Theme.colors.surface

            Image {
                anchors.fill: parent
                source: "file:///usr/local/share/ikigai/theme/wallpaper.jpg"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Loader {
                anchors.centerIn: parent
                active: modelData === Quickshell.screens[0]
                focus: true
                sourceComponent: Login {}
            }
        }
    }
}
