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
| Updates | Git pull + numbered migrations + `pacman -Syu` |
| Config ownership | **Seed, then hand off** — install writes COSMIC defaults once; afterward only `ikigai-theme-set` and surgical migrations touch `~/.config/cosmic` |
| Choices | None. No install-time pickers. |
| Terminal | Ghostty |
| Shell | zsh + starship |
| Browser | Zen (`zen-browser-bin`, AUR — accepted risk) |
| Editor | Zed primary; Neovim installed as themed sidekick |
| Runtimes | Docker + mise |
| Keybinds | Stock COSMIC + Super-key app layer (Super+Return/B/E) + cheatsheet cmd |
| Theming | Hand-curated theme dirs; **Tokyo Night** is the default and only launch theme |
| Hardware | AMD/Intel first-class; NVIDIA best-effort (driver installed, honestly documented); VM install is the named demo path |
| License | MIT, public from first commit |
| QA | shellcheck + container dry-run in CI; scripted QEMU fresh-install smoke test before tags; migrations tested against an aged-install snapshot |

## v1 cutline

**In:** installer, Tokyo Night, update/migration machinery, keybind layer + cheatsheet.
**Out (v2+):** ISO, additional themes, theme-switcher UI, `ikigai-doctor`, custom pacman repo.

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
mise, btop, ripgrep, fd, fzf, bat, eza, wl-clipboard, ttf-jetbrains-mono-nerd,
noto-fonts(-emoji). AUR: paru-bin (helper), zen-browser-bin.

## Build order

1. **Skeleton + happy path.** boot.sh → install.sh → packages.sh in a QEMU VM:
   fresh Arch minimal → reboot into COSMIC login. Nothing else.
2. **Seed + theme.** configs.sh + Tokyo Night across COSMIC/Ghostty/Zed/Neovim/btop.
   Research task here: exact COSMIC RON keys for theme/panel/shortcuts (schema is
   version-sensitive — pin findings to the COSMIC version in `extra`).
3. **Update machinery.** ikigai-update, migration runner, state tracking.
   Test against a snapshot of the Phase-1 VM.
4. **Keybind layer + ikigai-keys.**
5. **CI + smoke test.** shellcheck, container dry-run of installer, scripted
   QEMU fresh-install script.
6. **README, screenshots, public launch.**

## Accepted risks

- COSMIC schema churn (mitigated by hand-off model + migration machinery)
- Zen browser youth + AUR dependency in installer
- "No choices" stance will generate opinion-war issues — by design
