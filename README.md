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
| Desktop | [COSMIC](https://system76.com/cosmic) from Arch `extra`, Tokyo Night everywhere, NASA black-hole wallpaper |
| Terminal | [Ghostty](https://ghostty.org) + [zellij](https://zellij.dev) (unlock-first keybinds, `zj` to attach) |
| Shell | zsh (no framework) + [starship](https://starship.rs), autosuggestions, syntax highlighting, oh-my-zsh's git aliases |
| Editor | [Zed](https://zed.dev); Neovim with a minimal themed config |
| Browser | [Zen](https://zen-browser.app) |
| Runtimes | [mise](https://mise.jdx.dev) — `mise use -g node@lts`; Docker + lazydocker |
| TUIs | yazi (`y`), lazygit (`lg`), btop |
| CLI | ripgrep, fd, fzf, bat, eza, dust, git-delta, tealdeer, jq — with `ls`/`cat`/`du`/`grep` aliased to the modern ones |
| Fonts | JetBrainsMono Nerd Font, Noto |

### Keys

Stock COSMIC bindings, plus:

| Key | |
|---|---|
| `Super+Return` / `Super+T` | Ghostty |
| `Super+E` | Zed |
| `Super+B` | Zen |
| `Super+Shift+/` | searchable cheatsheet of every binding (`ikigai-keys` in a terminal) |

## How it's put together

- **COSMIC config is shipped as system defaults** in `/usr/local/share/cosmic/`, which
  cosmic-config reads before `/usr/share`. Your own changes in Settings land in
  `~/.config/cosmic` and override per key — Ikigai never fights you for them.
- **App configs are seeded once** into `~/.config`, only where nothing exists. Your
  dotfiles are never overwritten (`IKIGAI_FORCE=1` if you want ours).
- **Theme files are Ikigai-owned** and re-applied by `ikigai-theme-set tokyo-night`.
- **No AUR helper in the installer.** AUR packages are built with `makepkg`; `paru`
  is installed (from source) for *you* to use afterwards.

Repo layout: `install/` (steps run by `install.sh`), `config/` (seeds), `themes/`
(Tokyo Night for every app + the built COSMIC theme), `bin/` (`ikigai-keys`,
`ikigai-theme-set`), `tools/cosmic-theme-gen` (dev-only: builds the COSMIC theme from
`builder.ron`), `scripts/vm.sh` (Hyper-V test harness).

## Hardware

AMD and Intel graphics are first-class. NVIDIA gets `nvidia-open-dkms` installed and
is otherwise best-effort — COSMIC on NVIDIA is upstream's problem before it's ours.
The reference test environment is a Hyper-V VM; that's the path we actually verify.

## Status

Early. Working end to end from the one-liner above; no update mechanism yet
(`git pull` in `~/.local/share/ikigai` + `pacman -Syu` + `paru -Sua` is the honest answer
for now). See [PLAN.md](PLAN.md) for decisions and what's next.

## License

MIT. Vendored third-party files are listed in [THIRD_PARTY.md](THIRD_PARTY.md).
