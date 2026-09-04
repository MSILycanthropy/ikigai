# qt6-base: unmap before role destroy

cosmic-comp (Smithay) drops a client's Wayland connection if the client commits to a
surface after destroying its layer-shell role. Qt's Wayland platform plugin does exactly
that in `QWaylandWindow::setVisible(false)`, so every Qt layer-shell client (Quickshell,
Vicinae, Ghostty) dies the first time it hides a window. Upstream: cosmic-comp#1590,
smithay#1979.

`wayland-unmap-before-role-destroy.patch` reorders the hide path: attach null + commit
first, then destroy the role. Verified against qt6-base 6.11.2 on cosmic-comp 1.7.0
(2026-09-01): hide, re-show and `LazyLoader` unload all survive.

`ikigai-qt-wayland` rebuilds only `libQt6WaylandClient.so` (the patched file compiles into
it; the `libqwayland.so` plugin is a thin shim and stays stock) from the installed
qt6-base's own release tarball, with Arch's configure options minus LTO and debug info.
`install/qt.sh` installs it under `/usr/local/lib/ikigai`, runs it once, and adds a pacman
hook so every qt6-base upgrade rebuilds it. State in `/var/lib/ikigai/qt-wayland`; source
cache and ccache in `/var/cache/ikigai/qt`, so a pkgrel bump rebuilds from cache in a
fraction of the time. `pacman -Qkk qt6-base` reports the one altered file.

If the patch ever stops applying, the hook fails loudly and the stock library stays: the
rail survives (it never unmaps) but the shell's overlays (Alt+Tab, the screenshot picker)
and Vicinae crash on close until the patch is updated; systemd restarts the shell.
