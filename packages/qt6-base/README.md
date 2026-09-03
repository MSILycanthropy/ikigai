# qt6-base: unmap before role destroy

cosmic-comp (Smithay) drops a client's Wayland connection if the client commits to a
surface after destroying its layer-shell role. Qt's Wayland platform plugin does exactly
that in `QWaylandWindow::setVisible(false)`, so every Qt layer-shell client (Quickshell,
Vicinae, Ghostty) dies the first time it hides a window. Upstream: cosmic-comp#1590,
smithay#1979.

`wayland-unmap-before-role-destroy.patch` reorders the hide path: attach null + commit
first, then destroy the role. Verified against qt6-base 6.11.2 on cosmic-comp 1.7.0
(2026-09-01): hide, re-show and `LazyLoader` unload all survive.

Until Ikigai ships a rebuilt `qt6-base` from its own repo, build only the Wayland plugin:

```sh
git clone https://gitlab.archlinux.org/archlinux/packaging/packages/qt6-base
cd qt6-base && makepkg --nobuild -s
patch -d src/qtbase -p1 < wayland-unmap-before-role-destroy.patch
# configure as the PKGBUILD does (INTERPROCEDURAL_OPTIMIZATION=OFF to skip LTO), then
ninja -C src/build qwayland
```

Outputs: `src/build/lib/libQt6WaylandClient.so.6.11.2` and
`src/build/lib/qt6/plugins/platforms/libqwayland.so`, dropped over the installed copies.
Redo on every qt6-base bump (`pacman -Qkk qt6-base` reports the two altered files).
