# System

What Ikigai changes below the desktop, and why. Everything here is a file under
`config/system/etc` or a line in `install/`; each is reversible.

## Secrets

gnome-keyring, unlocked by the greeter's PAM stack (`/etc/pam.d/ikigai-greeter`) with the
login password. Zen, Zed, gh, Vicinae and the Chromium apps
(`--password-store=gnome-libsecret`) keep their tokens there and never ask twice. The ssh
agent is gcr's; `SSH_AUTH_SOCK` is set by the session, passphrases land in the same
keyring.

## Displays

`ikigai-outputs` remembers each layout that has sat still and puts it back when the same
heads return different. On NVIDIA a DisplayPort monitor leaves the bus when it sleeps, so
waking is a hotplug; cosmic-comp's first page flip after the modeset fails, it falls back
to 60 Hz in connector order and saves that. `ikigai-outputs` undoes that. A change made in
Settings has no hotplug and sticks.

## Memory

zram the size of RAM, zstd, before any disk swap. `vm.swappiness=100` and no swap
readahead: swap is RAM, so the kernel should compress a build's idle pages before it drops
a game's mapped files.

systemd-oomd kills the one runaway app when the apps' slice has sat under memory pressure
or swap is nearly full. The shell and compositor are never candidates.

## Scheduler

sched_ext's LAVD instead of EEVDF, loaded by `scx_loader` at boot. EEVDF shares the CPU
per thread, so a 12-thread build drops a game to single digits. LAVD spots the tasks that
wake and sleep between frames and lets them preempt the build. `scxctl stop` is EEVDF
again, live.

## Boot and shutdown

`NetworkManager-wait-online` is masked: the desktop never waits on DHCP. A stuck service
gets 5 s at shutdown, Docker 30 to stop its containers.

## Firewall

ufw: deny incoming, allow outgoing. ssh is kept and rate-limited when sshd is enabled.
ufw-docker so published ports respect it; containers may still reach the host's DNS.
Applied once at first boot by `ikigai-firewall.service`, or by `ikigai-firewall` as root.

## Updates

`ikigai-update` is `pacman -Syu`, `paru -Sua`, a line for orphans and `.pacnew` files,
then a pull of Ikigai and a rerun of the installer steps that changed.

`paccache.timer` keeps three versions in the package cache. kernel-modules-hook keeps the
running kernel's modules through an upgrade, so USB, Wi-Fi and Docker's netfilter survive
until you reboot.

## Fixes

- ssh notices a dropped connection within a minute (`/etc/ssh/ssh_config.d`; `~/.ssh/config` wins).
- The Wi-Fi regulatory domain follows the timezone's country.
- Apple keyboards get F-keys on the F row (`hid_apple fnmode=2`).
- `powerprofilesctl` is pinned to the system python, re-pinned by a pacman hook, so a mise python cannot break it.
- Cosmic Files is pinned for folders so no other entry wins `inode/directory`.
- Zen is the default for links and PDFs at the lowest XDG layer; Settings' Default Apps overrides it.

## NVIDIA

The AUR 580xx branch, pinned: the 610.x open modules crash Proton games with Xid 109.
`ikigai-doctor` nags while the pin is in. Idle-suspend on AC is off everywhere, since
resume on NVIDIA is not set up.

## Gaming

Not installed by default. `ikigai-steam` installs Steam, the 32-bit driver, gamemode,
gamescope, mangohud and `ttf-liberation`, adds you to the gamemode group, seeds
`~/.config/gamemode.ini` with `renice=10` (gamemode's own default renices nothing), pins
Steam to the rail and launches it. Proton comes with Steam; protonup-qt for Proton-GE.

## Docker

You are in the `docker` group, which is root-equivalent.
