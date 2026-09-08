# Ikigai

An opinionated developer workstation on **Arch Linux**: COSMIC's compositor underneath,
Ikigai's own shell on top.

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

**On Windows, no USB stick?** From an administrator PowerShell, with Secure Boot off in
your firmware and BitLocker off:

```powershell
irm https://raw.githubusercontent.com/MSILycanthropy/ikigai/main/boot.ps1 | iex
```

It asks whether to replace Windows or dual boot, puts the Arch ISO on a small new
partition, boots it once, and the ISO runs the `archinstall` line above for you. Windows
stays intact until you confirm the disk in archinstall; before that, `-Undo` puts
everything back. Dual boot keeps Windows' boot partition and adds Ikigai next to it,
with both on systemd-boot's menu; back in Windows, run it once with `-Clean`.

Either way: one sudo prompt, ~10 minutes, `sudo reboot` into the Ikigai greeter. There
is no setup wizard: locale and keyboard come from archinstall or the system you had.

**Supported** means a fresh minimal Arch (what the config above produces) — that's what
gets tested. On an Arch box that already has a desktop it *works*, best-effort: Ikigai
won't touch your dotfiles, but its greeter takes over `display-manager.service` from
whichever one you had, and cosmic-comp's defaults land as system config next to yours.

## What you get

| | |
|---|---|
| Desktop | [COSMIC](https://system76.com/cosmic)'s compositor, Settings, Files, portal and daemons from Arch `extra`. The panel, launcher, notifications, OSD, greeter, lock and polkit prompt are Ikigai's; COSMIC's versions are not installed. NASA black-hole wallpaper |
| Theme | One palette, `themes/ikigai/palette.json`: Material 3 neutrals seeded from the wallpaper's orange (near-black warm greys), the accent from its blue, and an ANSI 16 built in OKLCH. `scripts/theme-build.py` renders it into the rail, COSMIC (window chrome, libcosmic apps), Ghostty, btop, Vicinae, a libadwaita `gtk.css` that adw-gtk3 and Qt's gtk3 platform theme carry to GTK 3 and Qt apps, and the cursors. Every other terminal tool follows the terminal's ANSI colours |
| Rail | Ikigai's own [Quickshell](https://quickshell.org) shell: a thin autohiding rail inside a rounded frame, popouts that melt out of it. Pinned and running apps (click to focus, again to minimize, middle-click to close, right-click to pin or move), a task view of workspaces and windows, tray, volume card with output picker, clock. The look, and the blob renderer that draws it, are [soramanew's caelestia-shell](https://github.com/caelestia-dots/shell) — see [Credits](#credits) |
| Notifications | Toasts out of the rail, a sidebar (click the clock) with the history, a calendar and do-not-disturb, an unread badge. Volume and brightness changes show a pill at the bottom edge |
| Launcher | [Vicinae](https://vicinae.com) on `Super`: apps, files, clipboard history, and its own log out, power off, reboot and sleep commands. It arrives as a drop: the frame's top border swells, a droplet stretches out on a neck, snaps free and lands in the centre as the card, and Vicinae's window (chrome transparent, `config/vicinae/settings.json`) opens on it as it settles. Escape, a launch or a click beside it lifts the card back into the border (`shell/Launcher.qml`; `ikigai-shell launcher toggle`) |
| Greeter | Ikigai's, on greetd: cosmic-comp in kiosk mode drawing the same card as the lock screen, with the theme and wallpaper, your avatar from Settings, and the last user preselected, on their primary screen |
| Lock | `Super+L`, the idle timeout or the lid: logind locks, the shell draws the card over every screen and checks the password through PAM. The same card answers polkit when an app asks for privilege. Both cards repeat what PAM says: after three wrong passwords Arch's faillock shuts the account for ten minutes, and the card says so, with the minutes left, instead of shaking at the right password |
| Secrets | gnome-keyring, unlocked by the greeter's PAM stack (`/etc/pam.d/ikigai-greeter`) with the password that logged you in, so Zen, Zed, gh, Vicinae and the Chromium apps (`--password-store=gnome-libsecret` on their entries) keep their tokens in the login keyring and never ask for a second password. The ssh agent is gcr's (`gcr-ssh-agent.socket`, `SSH_AUTH_SOCK` set by the session): passphrases land in the same keyring |
| Displays | The layout survives the monitors' sleep. On NVIDIA a DisplayPort monitor leaves the bus when it powers down, so waking it is a hotplug to cosmic-comp, whose first page flip after the modeset the driver rejects; it falls back to 60 Hz in connector order and saves that as your layout. `ikigai-outputs` (a wlr-output-management client under the session target) remembers each layout that has sat still and puts it back in one configuration when the same heads return different. A change made in Settings comes with no hotplug and sticks |
| First login | A welcome card on the shell: the keys, the rail, where settings live, and a Connect to Wi-Fi button when the box is offline. Once per user (`~/.local/state/ikigai/welcomed`); `ikigai-shell welcome open` brings it back |
| Network | NetworkManager, on the rail: the Wi-Fi strength or the wired link as the glyph, a card with the Wi-Fi switch, the wired link and the networks in range. Click to connect; a new secured network asks for its password in a window; the connected row expands to Disconnect and Forget. cosmic-settings' Network page for VPNs and the rest |
| Battery | On the rail when there is one: level and charging state as the glyph, a card with the time left and the power profile (upower, power-profiles-daemon) |
| Bluetooth | bluez, enabled at install, on the rail when there is an adapter: the glyph says off, on or connected, the card has the switch, the paired devices and what is in range (it searches while open). Click connects or pairs and trusts; the connected row expands to Disconnect and Forget; battery level where the device reports one. Pairing that wants a PIN or a confirmation is cosmic-settings' Bluetooth page, the card carries no agent |
| Settings | cosmic-settings, with the rail in place of its panel: the Panel and Dock pages are inert, everything else works. The rail's own settings (pins, autohide, scale, the primary monitor, restore, `taskbar`) are in `~/.config/ikigai/shell.json` for now |
| Monitors | The rail is on every screen. `monitor` in `shell.json` names the primary: toasts, the lock, polkit and welcome cards go there, the greeter's card too (the shell leaves the name in `/var/lib/ikigai/greeter/<user>` for it), and the Alt+Tab switcher follows the focused window. `"taskbar": "screen"` makes each rail show only its own screen's windows, Windows' "where the window is open" option; the default `"all"` shows every window on every rail |
| Restore | Log back in and the apps you had open come back, each on the output and workspace it was on, maximized if it was, the way macOS reopens windows and Windows restarts apps. The shell keeps `~/.local/state/ikigai/session.json` current while you work and replays it once per login. What comes back is the app, not its contents: Zen and Zed remember their own, a terminal opens fresh. `"restore": false` in `shell.json` turns it off |
| Video | [mpv](https://mpv.io) with hardware decoding, fuzzy subtitle matching and resume-where-you-left-off seeded |
| Images | [cosmic-viewer](https://github.com/pop-os/cosmic-viewer), COSMIC's own image viewer: crop, rotate, markup, set as wallpaper (AUR `cosmic-viewer-git`) |
| Screenshots | `Print` freezes the screen and opens the shell's picker: Region, Window or Screen, then Snip, Edit or Record. Snip puts the PNG on the clipboard and in `~/Pictures/Screenshots`; Edit opens it in [satty](https://github.com/gabm/Satty); Record starts [gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/) on it with the system's audio, shows a dot and timer on the rail, and `Super+Shift+R` or a click on the dot stops it with the file's path (`~/Videos/Recordings`) on the clipboard. `Shift+Print` starts in Screen mode. Captured by [grim](https://gitlab.freedesktop.org/emersion/grim) over ext-image-copy-capture |
| Switcher | Windows-style Alt+Tab in the rail's language: hold Alt, Tab cycles live previews most-recent-first across workspaces (minimized included), release to switch, Shift+Tab backwards, Escape cancels, click a tile. It opens on the screen of the focused window, the primary when nothing is. Previews come from the bridge over ext-image-copy-capture |
| Mouse | Middle-click autoscroll the way Windows has it: per app, with each app's own anchor icon and pan cursors. Zen's is Firefox's, switched on as a default by `/etc/zen/policies/policies.json` (Settings can turn it off again). Discord and YouTube Music get Chromium's, which the Linux build hides behind `--enable-blink-features=MiddleClickAutoscroll`, from desktop-entry overlays in `/usr/local/share/applications`. GTK, Qt and COSMIC apps have none, as their Windows counterparts mostly didn't |
| Cursor | [Bibata](https://github.com/ful1e5/Bibata_Cursor) Modern in the palette: its SVG sources are vendored (`cursors/bibata`, GPL-3) and `theme-build.py` swaps their placeholder colours for the theme's, body and outline from the surface pair, the wait pie and the four corners from the ANSI colours, badges from the accents. It lands as an `Ikigai` cursor theme next to the icons: the SVG form for cosmic-comp, which renders it at any scale, and Xcursor files at 24 to 96 px that `ikigai-theme-set` rasterises for GTK, Qt and Chromium |
| Icons | [Phosphor](https://phosphoricons.com) everywhere: the rail's glyphs, and an `Ikigai` symbolic icon theme built from Phosphor that COSMIC's window buttons, cosmic-settings, GTK header bars and Qt apps all pick up. Ghostty, Zen and Zed get hand-drawn marks in Phosphor's grammar on the rail (`shell/icons/brand`), and apps Phosphor has a logo for (Chrome, Slack, Spotify, Telegram, Element, Steam and more, `shell/Apps.qml`) get it too; app icons elsewhere stay their own |
| Terminal | [Ghostty](https://ghostty.org) + [zellij](https://zellij.dev) (unlock-first keybinds, `zj` to attach) |
| Shell | zsh (no framework) + [starship](https://starship.rs), autosuggestions, syntax highlighting, oh-my-zsh's git aliases |
| Editor | [Zed](https://zed.dev) (Tokyo Night, fetched from Zed's registry on first launch: the one app not on the Ikigai theme); Neovim with a minimal config on the terminal palette |
| Browser | [Zen](https://zen-browser.app), the default for links and PDFs (`/usr/local/share/applications/mimeapps.list`, the lowest XDG layer; Settings' Default Apps page overrides it) |
| Apps | [Discord](https://discord.com) and [YouTube Music](https://github.com/pear-devs/pear-desktop) (th-ch's desktop app, now Pear Desktop, AUR `pear-desktop-bin`), pinned at the bottom of the rail |
| Dev | [gh](https://cli.github.com), [just](https://just.systems), and [Claude Code](https://code.claude.com) through its native installer (`~/.local/bin/claude`, updates itself) |
| Runtimes | [mise](https://mise.jdx.dev) — `mise use -g node@lts`; Arch builds mise without `self-update`, pacman updates it. Docker + lazydocker (you're added to the `docker` group, which is root-equivalent) |
| TUIs | yazi (`y`), lazygit (`lg`), btop |
| CLI | ripgrep, fd, fzf, bat, eza, dust, git-delta, tealdeer, jq, zip/unzip, plocate, fastfetch (with the black holes as its logo) — with `ls`/`cat`/`du`/`grep` aliased to the modern ones |
| Fonts | JetBrainsMono Nerd Font, Noto with its CJK and emoji faces, so Japanese, Chinese and Korean text renders instead of boxes |
| Firewall | ufw, deny incoming and allow outgoing, ssh kept (rate-limited against brute force) when sshd is enabled; ufw-docker so Docker's published ports respect it |
| Memory | zram: compressed swap the size of RAM, zstd, before any disk swap. systemd-oomd kills the one runaway app when the apps' slice has sat under memory pressure, or swap is nearly full, instead of the box thrashing; the shell and compositor are never candidates |
| Scheduler | sched_ext's [LAVD](https://github.com/sched-ext/scx) instead of the kernel's EEVDF, loaded by `scx_loader` at boot. EEVDF shares the CPU fairly per thread, so a 12-thread build drops a game to single digits; LAVD, written for the Steam Deck, spots the tasks that wake and sleep between frames and lets them preempt the build, which barely slows. `scxctl stop` is EEVDF again, live |
| Boot, shutdown | graphical.target never waits on DHCP or Wi-Fi (`NetworkManager-wait-online` masked). At shutdown a stuck service gets 5 s, not 90; Docker keeps 30 to stop its containers cleanly |
| Fixes | ssh notices a dropped connection within a minute (`/etc/ssh/ssh_config.d`, `~/.ssh/config` wins). The Wi-Fi regulatory domain is set from your timezone's country. Apple-style keyboards get F-keys on the F row (`hid_apple fnmode=2`). `powerprofilesctl` is pinned to the system python so a mise-managed one cannot break it, re-pinned by a pacman hook after each upgrade |
| Updates | `ikigai-update` (below). `paccache.timer` trims the package cache weekly to three versions; kernel-modules-hook keeps the running kernel's modules through an upgrade, so USB, Wi-Fi and Docker's netfilter survive until you reboot |
| Gaming | Not installed by default. `ikigai-steam` installs Steam, the 32-bit driver for your GPU, gamemode (and puts you in its group, so `gamemoderun` can renice a game from your next login), gamescope and mangohud and launches it; Proton comes with Steam, [protonup-qt](https://github.com/DavidoTek/ProtonUp-Qt) for Proton-GE |

### Keys

cosmic-comp's stock bindings, plus:

| Key | |
|---|---|
| `Super`, `Super+A` | Vicinae |
| `Super+W` | task view: workspaces and their windows, on the rail |
| `Super+L` | lock |
| `Super+P` | Displays, in Settings |
| `Alt+Tab` / `Alt+Shift+Tab` | window switcher, Windows-style (hold, cycle, release) |
| `Super+Return` / `Super+T` | Ghostty |
| `Super+E` | Zed |
| `Super+B` | Zen |
| `Print` / `Shift+Print` | screenshot picker, starting in Region / Screen mode |
| `Super+Shift+R` | record the screen through the same picker; again to stop |
| `Super+Shift+/` | searchable cheatsheet of every binding (`ikigai-keys` in a terminal) |

Log out, power off, reboot and sleep are Vicinae commands rather than chords: `Super`,
type the word.

### Commands

| | |
|---|---|
| `ikigai-update` | `pacman -Syu`, `paru -Sua`, a line for orphans and `.pacnew` files if there are any, then pull Ikigai and rerun the installer steps that changed; `--no-pkg` / `--pkg` for one half |
| `ikigai-doctor` | is this box's Ikigai whole and current: installed commit, units, keyring and ssh agent, greeter, patched Qt, firewall, pacman timers, seeds |
| `ikigai-keys` | every binding (`--fzf` to search) |
| `ikigai-caffeinate` | keep the screen on, macOS's `caffeinate`: until Ctrl-C, `-t 90m` for a while, `-w PID` while a process lives, or `ikigai-caffeinate make -j8` while a command runs (exits with its status). It holds the same `org.freedesktop.ScreenSaver` inhibit mpv and Zen take for video, the one thing cosmic-idle honours: screen off, lock and idle-suspend all wait |
| `ikigai-steam` | Steam, gamemode, gamescope, mangohud and the 32-bit driver, then launches it |
| `ikigai-shell welcome open` | the first-login card again |

## How it's put together

- **COSMIC config is shipped as system defaults** in `/usr/local/share/cosmic/`, which
  cosmic-config reads before `/usr/share`. Your own changes in Settings land in
  `~/.config/cosmic` and override per key — Ikigai never fights you for them.
- **App configs are seeded once** into `~/.config`, only where nothing exists. Your
  dotfiles are never overwritten (`IKIGAI_FORCE=1` if you want ours).
- **Theme files are Ikigai-owned** and re-applied by `ikigai-theme-set ikigai`. Any
  COSMIC theme customised in Settings is backed up to `~/.local/state/ikigai/backup/`
  before being replaced.
- **The installer shows a step list**: spinner, elapsed time per step and the last log
  line under the running one; a failed step prints its last 20 log lines. Everything a
  step printed is in `~/.local/state/ikigai/install.log`. Without a terminal (archinstall,
  `IKIGAI_PLAIN=1`) it prints plain `==> [n/10]` lines instead.
- **No AUR helper in the installer.** AUR packages are built with `makepkg`; `paru`
  is installed (from source) for *you* to use afterwards.
- **One session.** `ikigai-session` (Rust, `session/`) starts cosmic-comp on its own,
  gets `WAYLAND_DISPLAY` from cosmic-comp's session socket and brings up
  `ikigai-session.target`: cosmic-bg, cosmic-settings-daemon and cosmic-idle under Ikigai
  unit names, `ikigai-bridge` (COSMIC's toplevel and workspace protocols on
  `$XDG_RUNTIME_DIR/ikigai-bridge.sock` as JSON lines), `ikigai-outputs` (the display layout, see Displays above) and `ikigai-shell` (the Quickshell
  shell from `/usr/local/share/ikigai/shell`). [Vicinae](https://vicinae.com) runs
  alongside as a layer-shell overlay on the patched Qt below, under its own desktop name
  because it refuses layer-shell on anything called COSMIC; its config is seeded once with
  the Ikigai theme and telemetry off, and its welcome tour runs on first login. The shell
  reads its theme from `~/.local/state/ikigai/shell-theme.json` (written by
  `ikigai-theme-set`) and your settings from `~/.config/ikigai/shell.json` (seeded once:
  pinned apps, autohide, scale, and `monitor`, the primary output: toasts, the lock,
  polkit and welcome cards and the Alt+Tab switcher go there, and so the apps you launch
  after them — empty for the first one the compositor lists, which is not necessarily the
  one in front of you); both reload live. cosmic-comp's shortcuts point at the shell over
  `ikigai-shell <target> <call>` (Quickshell IPC). `ikigai.desktop` is the only session
  entry.
- **The greeter is the shell.** greetd runs `ikigai-greeter` as its own user, under its
  own PAM service (Arch's login stack plus gnome-keyring): cosmic-comp
  in kiosk mode with the Quickshell greeter as its only client. No daemon: theme and
  wallpaper from `/usr/local/share/ikigai/theme`, users from `/etc/passwd`, avatars from
  AccountsService. When the card succeeds cosmic-comp exits with it and greetd starts the
  session.
- **Lock and polkit share the card.** `ikigai-session` listens to logind and relays Lock
  and Unlock to the shell, which draws ext-session-lock surfaces and checks the password
  through PAM. The shell is also the session's polkit agent, so an app asking for
  privilege gets the same card with what it wants written under the name.

Repo layout: `install/` (steps run by `install.sh`), `config/` (seeds), `themes/`
(`ikigai/palette.json` plus the app themes `scripts/theme-build.py` renders from it and the built COSMIC theme), `cursors/` (Bibata's SVG sources, vendored), `bin/` (`ikigai-update`, `ikigai-doctor`, `ikigai-keys`, `ikigai-caffeinate`,
`ikigai-theme-set`, `ikigai-shell`, `ikigai-shot`, `ikigai-greeter`), `session/` (Rust: `ikigai-session`, `ikigai-bridge`, `ikigai-outputs` and the session's
user units, built at install), `shell/` (the Quickshell shell, greeter and lock included), `greeter/` (greetd config and units), `tools/cosmic-theme-gen` (dev-only: builds the COSMIC theme from
`builder.ron`), `scripts/vm.sh` (QEMU test harness; `vm-hyperv.sh` is the same for Hyper-V from WSL2).

Developing: `just` lists the recipes. `just shell` runs the shell from the checkout in
place of the installed one with live reload (cosmic-comp's shortcuts follow it), `just
greeter` opens the greeter in a nested cosmic-comp window, `just install <step>` runs one
installer step from the checkout, `just update` reruns the steps that changed since the
installed commit, `just doctor` says what is installed, running, patched and drifted, and
`just vm ...` drives the test VM.

## Hardware

AMD and Intel graphics are first-class. NVIDIA gets `nvidia-open-dkms` installed and
is otherwise best-effort — COSMIC on NVIDIA is upstream's problem before it's ours.
The reference test environment is a fresh install in a QEMU VM (`just vm`); that's the
path we actually verify.

## Status

v2: the shell replaced COSMIC's panel, launcher, notifications, OSD, greeter and lock,
and those packages are no longer installed. Both install paths work end to end.
`ikigai-update` pulls the checkout and reruns what changed; seeded configs are still
seed-once (edit yours, or `IKIGAI_FORCE=1`).

Not yet: a settings card for the rail, a chooser when polkit offers several admins,
a pairing agent on the Bluetooth card.

Next, roughly in order: those, reconciling seeded files on update `.pacnew`-style (the
seed hashes are already recorded), a custom pacman repo so the installer needs no
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
