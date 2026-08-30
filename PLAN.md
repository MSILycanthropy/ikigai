# Ikigai — Technical Plan

An opinionated, public, MIT-licensed developer workstation on **Arch + COSMIC**.
Omarchy's category (curated dev machine), not its shape: COSMIC provides the
desktop; Ikigai provides curation, theming, and ops tooling.

## Decisions (settled 2026-08-28)

| Area | Decision |
|---|---|
| Audience | Public from day one |
| Value prop | Curated dev workstation — the curation is the product |
| Base | Arch, COSMIC from official `extra` repo |
| COSMIC risk | Track Arch packages, own the breakage, ship migration fixes fast |
| Delivery | Bootstrap script on vanilla Arch; ISO later (v2+) |
| Updates | **Deferred (0 users).** Design when built: *reconcile*, not migrations — Ikigai-owned files are re-copied; user-seeded files use the `.pacnew` model (hash recorded at seed time; untouched → replace, edited → `<file>.ikigai-new` + diff). `migrations/` only for rare structural changes. v2: ship configs as a pacman package |
| Config ownership | **COSMIC:** ship defaults in `/usr/local/share/cosmic/` (cosmic-config's system layer; searched before `/usr/share`, not pacman-owned). User edits land in `~/.config/cosmic` and override per key. **Everything else:** seed into `~/.config` only if absent (`--force` to overwrite), then hand off. Only `ikigai-theme-set` and migrations touch seeded files afterward |
| Choices | None. No install-time pickers. `cosmic-initial-setup` (upstream) handles the per-user questions — language, keyboard, timezone, Wi-Fi, scaling, a11y. No fork; revisit only for a theme picker once ≥2 themes exist. Its greeter mode is the v2 ISO's OOBE. |
| Terminal | Ghostty + zellij (terminal-first workflow: yazi, lazygit, lazydocker, btop as the "apps") |
| Shell | zsh + starship |
| Browser | Zen (`zen-browser-bin`, AUR — accepted risk) |
| Editor | Zed primary; Neovim installed with a minimal themed `init.lua` (users with their own config keep it — seeds never overwrite existing files) |
| Runtimes | Docker + mise |
| Keybinds | Stock COSMIC + Super-key app layer (Super+Return/T terminal, Super+B browser, Super+E editor) + Super+Shift+/ cheatsheet |
| Theming | Hand-curated theme dirs; **Tokyo Night** is the default and only launch theme |
| Hardware | AMD/Intel first-class; NVIDIA best-effort (driver installed, honestly documented); VM install is the named demo path |
| License | MIT, public from first commit |
| QA | shellcheck + container dry-run in CI; scripted Hyper-V fresh-install smoke test (`scripts/vm.sh`) before tags; migrations tested against an aged-install checkpoint |
| AUR | Installer never calls an AUR helper: `makepkg` directly via `aur()` in `packages.sh`. `paru` is built from source (AUR `-bin` builds go stale on pacman soname bumps — hit 2026-08-29). Long-term fix is a custom repo (v2), Omarchy-style |

## v1 cutline

**In:** installer, Tokyo Night, keybind layer + cheatsheet.
**Out (v2+):** update machinery, ISO, additional themes, theme-switcher UI, `ikigai-doctor`, custom pacman repo.

## Repo layout

```
ikigai/
├── boot.sh                 # curl-able entry: installs git, clones to ~/.local/share/ikigai, execs install.sh
├── install.sh              # orchestrator: runs install/*.sh in order, logs, fails loud
├── install/
│   ├── preflight.sh        # Arch check, network, non-root w/ sudo, GPU detect (AMD/Intel/NVIDIA)
│   ├── packages.sh         # pacman set, AUR helper (paru), AUR set
│   ├── configs.sh          # seed ~/.config from config/ (copy, never symlink — hand-off model)
│   ├── theme.sh            # install + activate Tokyo Night
│   ├── keybinds.sh         # write COSMIC custom-shortcuts layer
│   └── services.sh         # enable docker, cosmic-greeter, timers
├── bin/                    # on PATH via zsh config
│   ├── ikigai-update       # git pull → run unapplied migrations → pacman -Syu
│   ├── ikigai-theme-set    # v1: re-applies tokyo-night; contract designed for N themes
│   └── ikigai-keys         # keybinding cheatsheet
├── config/                 # canonical seed configs
│   ├── cosmic/             # RON files: theme, panel/dock layout, shortcuts
│   ├── ghostty/
│   ├── zed/
│   ├── nvim/
│   ├── zsh/
│   └── starship.toml
├── themes/
│   └── tokyo-night/        # cosmic theme RON, ghostty colors, zed+nvim theme pointers,
│                           # btop/lazygit themes, wallpaper
├── migrations/             # <unix-timestamp>.sh, applied state in ~/.local/state/ikigai/
├── LICENSE
└── README.md
```

Update state model: `~/.local/share/ikigai` is the live checkout;
`~/.local/state/ikigai/migrations/` records applied migration filenames.
`ikigai-update` runs anything in `migrations/` not recorded there, oldest first.

## Curated package set (draft — finalize in Phase 1)

cosmic, ghostty, zsh, starship, zed, neovim, lazygit, docker, docker-compose,
mise, zellij, yazi, lazydocker, btop, ripgrep, fd, fzf, bat, eza, dust, git-delta,
tealdeer, jq, wl-clipboard, ttf-jetbrains-mono-nerd, noto-fonts(-emoji), pipewire
stack, `hyperv` (Hyper-V guests only). Aliases: ls→eza, cat→bat, du→dust, grep→rg.
No zoxide/atuin (deliberate).
AUR (via makepkg): paru (source), zen-browser-bin.

## Build order

1. **Skeleton + happy path.** boot.sh → install.sh → packages.sh in a Hyper-V VM:
   fresh Arch minimal → reboot into COSMIC login. Nothing else. ✅ 2026-08-29
2. **Seed + theme.** Researched 2026-08-29 against COSMIC `epoch-1.7.0`:
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
   Steps: (a) non-COSMIC configs + `configs.sh` ✅ (b) COSMIC theme via generator + `CosmicTk` ✅
   (c) wallpaper (NASA SVS 13831, public domain) + `system_actions` + `custom` shortcuts +
       dock favorites (`CosmicAppList/v1/favorites`; the applet reads it at login only) ✅
   (d) `ikigai-theme-set` + full clean-install verification.
3. **Update machinery — deferred.** Only prerequisite now: `install.sh` records the
   installed commit and `configs.sh` records seed hashes, so early installs aren't stranded.
4. **`ikigai-keys` cheatsheet.** ✅ 2026-08-30. Parses `defaults` + `custom` + `system_actions`
   at runtime (same merge cosmic-comp does), grouped; `--fzf` for search. Bound to
   Super+Shift+/ (keysym `slash` with Shift — not `question`). `bin/` is symlinked into
   `/usr/local/bin` at install so compositor `Spawn` can find it.
5. **CI + smoke test.** ✅ 2026-08-30. GitHub Actions: shellcheck (severity warning,
   `config/` `themes/` `tools/` excluded — zsh + vendored) and an `archlinux:latest` job
   running `scripts/ci-check.sh` (bash -n, every curated package resolves via
   `pacman -Sp`, GPU/VM packages exist, no empty config files). The fresh-install smoke
   test stays manual on Hyper-V via `scripts/vm.sh` (QEMU/WHPX on Windows was abandoned —
   MSI/MMIO emulation failures and a corrupted image).
6. **README, screenshots, public launch.**

## Accepted risks

- COSMIC schema churn (mitigated by hand-off model + migration machinery)
- Zen browser youth + AUR dependency in installer
- "No choices" stance will generate opinion-war issues — by design
