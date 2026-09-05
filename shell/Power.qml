pragma Singleton
import Quickshell
import Quickshell.Services.UPower

// The battery and the power profile: UPower's display device (the one battery a laptop
// shows) and power-profiles-daemon, both started on demand over D-Bus.
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool present: device !== null && device.ready && device.isPresent && device.type === UPowerDeviceType.Battery
    readonly property real percentage: present ? device.percentage : 0
    readonly property bool charging: present && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: present && device.state === UPowerDeviceState.FullyCharged
    readonly property bool low: present && !charging && percentage <= 10
    readonly property string icon: charging ? "battery-charging" : percentage <= 5 ? "battery-empty" : percentage <= 25 ? "battery-low" : percentage <= 50 ? "battery-medium" : percentage <= 85 ? "battery-high" : "battery-full"
    readonly property string status: !present ? "" : full ? "Fully charged" : charging ? "Charging" + span(device.timeToFull, "to full") : "On battery" + span(device.timeToEmpty, "left")

    readonly property var profiles: [
        { profile: PowerProfile.PowerSaver, icon: "leaf", label: "Saver" },
        { profile: PowerProfile.Balanced, icon: "scales", label: "Balanced" },
        { profile: PowerProfile.Performance, icon: "rocket-launch", label: "Performance" },
    ]

    function span(seconds, suffix) {
        if (seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600), m = Math.round((seconds % 3600) / 60);
        return ", " + (h > 0 ? h + " h " : "") + m + " min " + suffix;
    }

    function setProfile(profile) {
        PowerProfiles.profile = profile;
    }
}
