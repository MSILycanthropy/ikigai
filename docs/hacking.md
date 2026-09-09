# Hacking

## Layout

| | |
|---|---|
| `boot.sh`, `boot.ps1`, `windows/live.sh`, `archinstall.json` | the entry points |
| `install.sh`, `install/` | the installer and its ten steps |
| `bin/` | `ikigai-*` commands and the `zed` wrapper, onto `/usr/local/bin` |
| `config/` | seeds for `~/.config`, COSMIC system config, `system/etc` |
| `shell/` | the Quickshell shell, greeter and lock included. `plugin/blobs` is vendored |
| `session/` | Rust: `ikigai-session`, `ikigai-bridge`, `ikigai-outputs`, their units |
| `greeter/` | greetd config, PAM, units |
| `themes/` | `<name>/palette.json` and what `theme-build.py` renders from it |
| `cursors/bibata` | Bibata's SVG sources, vendored |
| `icons/` | the Ikigai icon theme and its Phosphor name map |
| `packages/qt6-base` | the Wayland patch, its rebuild script and pacman hook |
| `firewall/` | the first-boot unit |
| `tools/cosmic-theme-gen` | dev-only: builds the COSMIC theme from `builder.ron` |
| `scripts/` | theme pipeline, vendoring, dev shell, the VMs, CI |

## Recipes

`just` lists them. Local ones act on the box you are sitting at.

| | |
|---|---|
| `just shell` | the shell from this tree in place of the installed one, live reload; Ctrl+C restores. cosmic-comp's shortcuts follow it |
| `just greeter` | the greeter in a nested cosmic-comp window, real PAM |
| `just ipc [target call]` | call into the running shell; no arguments lists targets |
| `just bridge`, `just logs` | follow the bridge socket, the session's units |
| `just shot [kind]` | a screenshot through the picker |
| `just install <step>` | one installer step from this tree. `-- IKIGAI_FORCE=1` for env |
| `just update` | rerun the steps that changed since the installed commit |
| `just restart` | the shell and bridge units |
| `just theme [name]` | build the theme files and apply them |
| `just doctor`, `just config-diff` | what is drifted; seeds vs `config/` |
| `just check` | bash -n, shellcheck, clippy and tests, config sanity |
| `just ci` | the full CI check in an archlinux container |
| `just vm ...` | the QEMU VM |

## The VM

`scripts/vm.sh`, QEMU/KVM with user-mode networking. `fetch`, `create`, `install`, then
`seal` freezes the vanilla install as a read-only base and every `run` is an overlay;
`reset` throws it away. `ssh`, `sync`, `serve` for iterating; `VM_OUTPUTS=2` for the
multi-output paths. `vm-hyperv.sh` is the same from WSL2. Needs qemu-desktop and edk2-ovmf.

## Vendoring

Each `scripts/vendor-*.sh` pins a revision and rewrites its target: the blob plugin, the
cursors, the icon theme, the glyph table, oh-my-zsh's git aliases. Add a row to
`THIRD_PARTY.md` when adding one.

## CI

shellcheck at warning, and `scripts/ci-check.sh` in an archlinux container: syntax on
every script and every curated package name resolves in the official repos.

## Adding a step

A file in `install/`, its name in `STEPS` in `install.sh`, and a line in `just update`
mapping the paths it reads to its name, so `ikigai-update` knows when to rerun it.
