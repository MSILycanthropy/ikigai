# Ikigai

An opinionated developer workstation on **Arch Linux + COSMIC**.

No questions. No bullshit.

![Ikigai desktop](docs/desktop.png)

## Install

Ikigai is to Arch what Proxmox is to Debian: it layers onto an existing install rather
than replacing it. Two ways in, one installer.

**Already on Arch?** From the machine, or SSH'd into it:

```sh
curl -fsSL https://raw.githubusercontent.com/MSILycanthropy/ikigai/main/boot.sh | bash
```

**Not yet?** Boot the [official Arch ISO](https://archlinux.org/download/) and let
`archinstall` do the base install with Ikigai's config — it preselects the minimal
profile, systemd-boot and NetworkManager, asks you only for disk, user, password and
timezone, then runs the line above for you:

```sh
archinstall --config-url https://raw.githubusercontent.com/MSILycanthropy/ikigai/main/archinstall.json
```

(To do that from another machine: on the live ISO run `passwd`, `systemctl start sshd`,
`ip -br addr`, then `ssh root@<ip>` and run it there.)

Either way: one sudo prompt, ~10 minutes, `sudo reboot` into the COSMIC greeter.
First login runs COSMIC's own setup wizard (language, keyboard, Wi-Fi, scaling,
accessibility); everything else is already done.

**Supported** means a fresh minimal Arch (what the config above produces) — that's what
gets tested. On an Arch box that already has a desktop it *works*, best-effort: Ikigai
won't touch your dotfiles, but two greeters will be enabled and yours may win.

## What you get

| | |
|---|---|
| Desktop | [COSMIC](https://system76.com/cosmic) from Arch `extra`, NASA black-hole wallpaper |
| Theme | One palette, `themes/ikigai/palette.json`: Material 3 neutrals seeded from the wallpaper's orange (near-black warm greys), the accent from its blue, and an ANSI 16 built in OKLCH. `scripts/theme-build.py` renders it into the rail, COSMIC (window chrome, libcosmic apps), Ghostty, btop, Vicinae and a libadwaita `gtk.css` that adw-gtk3 and Qt's gtk3 platform theme carry to GTK 3 and Qt apps. Every other terminal tool follows the terminal's ANSI colours |
| Rail | Ikigai's own [Quickshell](https://quickshell.org) shell (the experimental "Ikigai" session): a thin autohiding rail inside a rounded frame, popouts that melt out of it. The look, and the blob renderer that draws it, are [soramanew's caelestia-shell](https://github.com/caelestia-dots/shell) — see [Credits](#credits) |
| Screenshots | `Print` freezes the screen and opens the shell's picker: Region, Window or Screen, then Snip, Edit or Record. Snip puts the PNG on the clipboard and in `~/Pictures/Screenshots`; Edit opens it in [satty](https://github.com/gabm/Satty); Record starts [gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/) on it with the system's audio, shows a dot and timer on the rail, and `Super+Shift+R` or a click on the dot stops it with the file's path (`~/Videos/Recordings`) on the clipboard. `Shift+Print` starts in Screen mode. Captured by [grim](https://gitlab.freedesktop.org/emersion/grim) over ext-image-copy-capture; under stock COSMIC the same keys use slurp in the same colours |
| Switcher | Windows-style Alt+Tab in the rail's language: hold Alt, Tab cycles live previews most-recent-first across workspaces (minimized included), release to switch, Shift+Tab backwards, Escape cancels, click a tile. Previews come from the bridge over ext-image-copy-capture |
| Icons | [Phosphor](https://phosphoricons.com) everywhere: the rail's glyphs, and an `Ikigai` symbolic icon theme built from Phosphor that COSMIC's window buttons, cosmic-settings, GTK header bars and Qt apps all pick up. Ghostty, Zen and Zed get hand-drawn marks in Phosphor's grammar on the rail (`shell/icons/brand`); app icons elsewhere stay their own |
| Terminal | [Ghostty](https://ghostty.org) + [zellij](https://zellij.dev) (unlock-first keybinds, `zj` to attach) |
| Shell | zsh (no framework) + [starship](https://starship.rs), autosuggestions, syntax highlighting, oh-my-zsh's git aliases |
| Editor | [Zed](https://zed.dev) (Tokyo Night, fetched from Zed's registry on first launch: the one app not on the Ikigai theme); Neovim with a minimal config on the terminal palette |
| Browser | [Zen](https://zen-browser.app) |
| Apps | [Discord](https://discord.com) and [YouTube Music](https://github.com/pear-devs/pear-desktop) (th-ch's desktop app, now Pear Desktop, AUR `pear-desktop-bin`), pinned at the bottom of the rail |
| Runtimes | [mise](https://mise.jdx.dev) — `mise use -g node@lts`; Docker + lazydocker (you're added to the `docker` group, which is root-equivalent) |
| TUIs | yazi (`y`), lazygit (`lg`), btop |
| CLI | ripgrep, fd, fzf, bat, eza, dust, git-delta, tealdeer, jq — with `ls`/`cat`/`du`/`grep` aliased to the modern ones |
| Fonts | JetBrainsMono Nerd Font, Noto |

### Keys

Stock COSMIC bindings, plus:

| Key | |
|---|---|
| `Super` | Vicinae |
| `Alt+Tab` / `Alt+Shift+Tab` | window switcher, Windows-style (hold, cycle, release) |
| `Super+Return` / `Super+T` | Ghostty |
| `Super+E` | Zed |
| `Super+B` | Zen |
| `Print` / `Shift+Print` | screenshot picker, starting in Region / Screen mode |
| `Super+Shift+R` | record the screen through the same picker; again to stop |
| `Super+Shift+/` | searchable cheatsheet of every binding (`ikigai-keys` in a terminal) |

## How it's put together

- **COSMIC config is shipped as system defaults** in `/usr/local/share/cosmic/`, which
  cosmic-config reads before `/usr/share`. Your own changes in Settings land in
  `~/.config/cosmic` and override per key — Ikigai never fights you for them.
- **App configs are seeded once** into `~/.config`, only where nothing exists. Your
  dotfiles are never overwritten (`IKIGAI_FORCE=1` if you want ours).
- **Theme files are Ikigai-owned** and re-applied by `ikigai-theme-set ikigai`. Any
  COSMIC theme customised in Settings is backed up to `~/.local/state/ikigai/backup/`
  before being replaced.
- **No AUR helper in the installer.** AUR packages are built with `makepkg`; `paru`
  is installed (from source) for *you* to use afterwards.
- **An "Ikigai" session entry, experimental.** `ikigai-session` starts cosmic-comp on
  its own, gets `WAYLAND_DISPLAY` from cosmic-comp's session socket and brings up
  `ikigai-session.target`; `ikigai-bridge` under it exposes COSMIC's toplevel and
  workspace protocols on `$XDG_RUNTIME_DIR/ikigai-bridge.sock` as JSON lines; `ikigai-shell`
  runs the Quickshell shell from `/usr/local/share/ikigai/shell`: an autohiding bottom bar
  with a Windows-style taskbar (pinned + running apps, click to focus or minimize,
  middle-click to close, right-click for pin/unpin, move to workspace, close), a task-view
  button that switches workspaces, and a clock. [Vicinae](https://vicinae.com) is the
  launcher (Super, or the start and search buttons), running as a layer-shell overlay on
  the patched Qt below; its config is seeded once with the Ikigai theme and telemetry off, and
  its welcome tour runs on first login. The shell reads its theme from
  `~/.local/state/ikigai/shell-theme.json` (written by `ikigai-theme-set`) and your settings
  from `~/.config/ikigai/shell.json` (seeded once: pinned apps, alignment, autohide, scale); both reload
  live. Not yet: per-monitor window lists, drag to reorder pins. Stock COSMIC stays the
  default in the greeter.

Repo layout: `install/` (steps run by `install.sh`), `config/` (seeds), `themes/`
(`ikigai/palette.json` plus the app themes `scripts/theme-build.py` renders from it and the built COSMIC theme), `bin/` (`ikigai-keys`,
`ikigai-theme-set`), `session/` (Rust: `ikigai-session` + `ikigai-bridge` and the session's
user units, built at install), `shell/` (the Quickshell shell), `tools/cosmic-theme-gen` (dev-only: builds the COSMIC theme from
`builder.ron`), `scripts/vm.sh` (Hyper-V test harness).

## Hardware

AMD and Intel graphics are first-class. NVIDIA gets `nvidia-open-dkms` installed and
is otherwise best-effort — COSMIC on NVIDIA is upstream's problem before it's ours.
The reference test environment is a Hyper-V VM; that's the path we actually verify.

## Status

Early. Both install paths work end to end. No update mechanism yet — `git pull` in
`~/.local/share/ikigai` + `pacman -Syu` + `paru -Sua` is the honest answer for now.

Next, roughly in order: an update command (reconcile seeded files `.pacnew`-style —
the seed hashes are already recorded), a custom pacman repo so the installer needs no
AUR at all, an ISO with an SSH-first console, a second theme
(the palette pipeline and `tools/cosmic-theme-gen` are ready for it).

Notes on how COSMIC's config layering actually works: [docs/cosmic-config.md](docs/cosmic-config.md).

## Credits

The rail is a port of [caelestia-shell](https://github.com/caelestia-dots/shell) by
[soramanew](https://github.com/soramanew): its frame-and-rail layout, its Material 3
motion, and above all its blob renderer, the Qt Quick plugin that draws every panel as a
signed distance field and melts them together. Ikigai vendors that plugin verbatim
(`shell/plugin/blobs`, `scripts/vendor-blobs.sh`) and re-implements the QML around it for
cosmic-comp. If you like how this looks, that's their work.

## License

MIT, except `shell/` which is GPL-3.0 because it builds on caelestia-shell's blob renderer. Vendored third-party files are listed in [THIRD_PARTY.md](THIRD_PARTY.md).
