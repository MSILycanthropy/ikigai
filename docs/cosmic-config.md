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
  `system_actions` maps `Terminal`/`WebBrowser` to commands. Super+E/Return unbound upstream.
- Greeter reads the same system theme layer; its wallpaper comes only from a user's
  cosmic-bg *state* (1.7.0 limitation) → matches after first login.
- App themes: vendor folke/tokyonight.nvim `extras/` (ghostty, btop, lazygit, fzf, eza,
  yazi, delta, sublime→bat). Zed: extension `tokyo-night` via `auto_install_extensions`.
  starship: hand-written `[palettes.tokyo_night]`. nvim: native `pack/*/start` clone.
