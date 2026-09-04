# COSMIC 1.7 config notes

What Ikigai relies on, verified 2026-08-29/30 against COSMIC `epoch-1.7.0` (Arch `extra`) and the libcosmic rev cosmic-settings 1.7.0 pins (`2a73fbc`). Re-verify at the next COSMIC bump.

- cosmic-config reads `~/.config/cosmic/<C>/v<N>/<key>`, then falls back per key to
  the first `$XDG_DATA_DIRS/cosmic/<C>/v<N>/<key>`. Session `XDG_DATA_DIRS` includes
  `/usr/local/share/` before `/usr/share/` (verified in VM) → Ikigai ships there.
- Theme is `CosmicTheme.Dark/v2` (37 derived keys). The `.Builder` is inert — nothing
  derives from it except cosmic-settings. v1: author a Tokyo Night `ThemeBuilder`,
  import in Settings on the VM, harvest the built `Dark/v2/*` into `themes/tokyo-night/`.
  **Superseded:** the Settings import fails silently on any RON error, so
  `tools/cosmic-theme-gen` (Rust, pinned to the same libcosmic rev) parses `builder.ron`
  and writes the built `Dark/v2` + `Dark.Builder/v2` files. Dev-time only; output is
  committed. Also fixes a real bug: upstream's shipped theme lacks `list_button`, so
  every COSMIC component logged "Failed to load the theme" at login.
- Fonts/icon theme: `CosmicTk/v1`. Wallpaper: `CosmicBackground/v1/{all,same-on-all}`
  (upstream's `all` has a RON syntax bug — `#true` — don't copy it).
- Shortcuts: `CosmicSettings.Shortcuts/v1/custom` extends `defaults` by key;
  `system_actions` maps `Terminal`/`WebBrowser` to commands and `WindowSwitcher`/
  `WindowSwitcherPrevious` (Alt+Tab, Alt+Shift+Tab) to `ikigai-shell switcher next|prev`
  instead of cosmic-launcher, and `Screenshot` (Print) to `ikigai-shot region` instead of
  cosmic-screenshot; `Shift+Print` → `ikigai-shot screen` is in `custom`. Super+E/Return
  unbound upstream.
- Greeter reads the same system theme layer; its wallpaper comes only from a user's
  cosmic-bg *state* (1.7.0 limitation) → matches after first login.
- App themes: vendor folke/tokyonight.nvim `extras/` (ghostty, btop, lazygit, fzf, eza,
  yazi, delta, sublime→bat). Zed: extension `tokyo-night` via `auto_install_extensions`.
  starship: hand-written `[palettes.tokyo_night]`. nvim: native `pack/*/start` clone.
- Session handshake (cosmic-comp `src/session.rs`): with `COSMIC_SESSION_SOCK=<fd>` set,
  cosmic-comp writes one message — native-endian `u16` length, then JSON
  `{"message":"set_env","variables":{"WAYLAND_DISPLAY":…,"DISPLAY":…}}` — and expects
  nothing back. `session/src/bin/ikigai-session.rs` mirrors that enum verbatim.
- Bridge pins cosmic-protocols `32283d7` (what cosmic-comp 1.7.0's Cargo.lock resolves).
  Toplevel manager is v4 (`move_to_ext_workspace`; the legacy `move_to_workspace` is a
  no-op in comp). ext-workspace `id` is only sent for pinned workspaces, so the bridge
  keys unpinned ones by Wayland object id.
- **The system layer is one directory, not a per-key merge.** cosmic-config resolves a
  config's system path with `find_data_file("<id>/v<N>")` and reads *every* key from that
  first hit. Shipping `com.system76.CosmicSettings.Shortcuts/v1/{custom,system_actions}`
  under `/usr/local/share/cosmic` therefore hid COSMIC's `defaults` (every stock binding,
  including Super for the launcher) and produced the `shortcuts defaults config error:
  GetKey("defaults", NotFound)` at every cosmic-comp start. `install/configs.sh` symlinks
  `defaults` to the `/usr/share` copy so upstream changes still flow. Any other config we
  overlay must ship all of its keys.
