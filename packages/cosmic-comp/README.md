# cosmic-comp: no primary selection

Middle-click paste is Wayland's primary selection: whatever text is highlighted anywhere,
a middle click pastes it. Windows never had it, and on a mouse with a wheel button it
fires by accident. There is no switch for it in Ghostty, Qt or COSMIC apps, and GTK, Zen
and Chromium each have their own, so Ikigai turns it off in the one place every app asks:
the compositor.

`no-primary-selection.patch` has cosmic-comp offer `zwp_primary_selection_device_manager_v1`
to no client (Smithay's `new_with_filter` with a filter that always says no). Every
Wayland app then sees no primary selection and pastes nothing on middle click; middle-click
autoscroll (README, Mouse) is unaffected, as is the real clipboard. X11 apps under XWayland
can still middle-click paste between themselves, since PRIMARY lives inside Xwayland; the
compositor no longer bridges it to Wayland apps. Verified against cosmic-comp 1.7.0
(2026-09-06).

`ikigai-cosmic-comp` rebuilds the binary from the installed package's own release tag
(`epoch-<version>`, what Arch's PKGBUILD builds) with the patches in
`/usr/local/share/ikigai/cosmic-comp`, Arch's flags (thin LTO, lld, makepkg's Rust flags,
no debug info), and installs it over `/usr/bin/cosmic-comp` by rename, so the running
session keeps its old binary and the next login gets the new one. `install/cosmic-comp.sh`
installs it under `/usr/local/lib/ikigai`, runs it once, and adds a pacman hook so every
cosmic-comp upgrade rebuilds it. State in `/var/lib/ikigai/cosmic-comp`; the crate cache
and target dir in `/var/cache/ikigai/cosmic-comp`, so a pkgrel bump or a patch tweak is an
incremental build. `pacman -Qkk cosmic-comp` reports the one altered file. The greeter runs
the same binary in kiosk mode and needs nothing.

If a patch ever stops applying, the hook fails loudly and the stock binary stays: nothing
breaks, middle-click paste is just back until the patch is updated.
