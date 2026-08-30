#!/usr/bin/env bash
# Drive a Hyper-V VM from WSL2 for fresh-install testing.
#
# Lifecycle: fetch → create → install → seal → run / reset.
# `seal` takes the `vanilla` checkpoint; `reset` rolls back to it.
set -euo pipefail

VM=${VM_NAME:-ikigai}
CPUS=${VM_CPUS:-4}
MEM=${VM_MEM:-4GB}
DISK_SIZE=${VM_DISK:-40GB}
SWITCH=${VM_SWITCH:-Default Switch}
ISO_MIRROR="https://geo.mirror.pkgbuild.com/iso/latest"

win_home="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
VM_DIR="$(wslpath -u "$win_home")/ikigai-vm"
ISO="$VM_DIR/archlinux-x86_64.iso"
VHDX="$VM_DIR/$VM.vhdx"

win() { wslpath -w "$1"; }
die() { echo "vm.sh: $*" >&2; exit 1; }
ps()  { powershell.exe -NoProfile -NonInteractive -Command "\$ErrorActionPreference='Stop'; $*" | tr -d '\r'; }
# WSL (mirrored networking) has no route to the Default Switch; the host does.
SSH=${VM_SSH:-ssh.exe}
ssh_opts() { printf '%s\n' -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR; }

vm_exists() { ps "Get-VM -Name '$VM' -ErrorAction SilentlyContinue | Out-Null; \$?" | grep -q True; }
vm_state()  { ps "(Get-VM -Name '$VM').State"; }

cmd_fetch() {
  mkdir -p "$VM_DIR"
  curl -fL --progress-bar -o "$ISO" "$ISO_MIRROR/archlinux-x86_64.iso"
  curl -fsSL -o "$ISO.sig" "$ISO_MIRROR/archlinux-x86_64.iso.sig"
  gpg --auto-key-locate clear,wkd -v --locate-external-key pierre@archlinux.org >/dev/null 2>&1 || true
  gpg --verify "$ISO.sig" "$ISO" || die "ISO signature verification failed"
  echo "fetched + verified $ISO"
}

cmd_create() {
  mkdir -p "$VM_DIR"
  vm_exists && die "VM '$VM' already exists (vm.sh destroy to start over)"
  ps "
    New-VM -Name '$VM' -Generation 2 -MemoryStartupBytes $MEM -SwitchName '$SWITCH' \
      -NewVHDPath '$(win "$VHDX")' -NewVHDSizeBytes $DISK_SIZE | Out-Null
    Set-VM -Name '$VM' -ProcessorCount $CPUS -CheckpointType Standard -AutomaticCheckpointsEnabled \$false
    Set-VMFirmware -VMName '$VM' -EnableSecureBoot Off
    Set-VMMemory -VMName '$VM' -DynamicMemoryEnabled \$false
  "
  echo "created VM '$VM' ($CPUS cpu, $MEM, $DISK_SIZE, switch '$SWITCH')"
}

cmd_install() {
  [ -f "$ISO" ] || die "no ISO; run: vm.sh fetch"
  vm_exists || die "no VM; run: vm.sh create"
  ps "
    Add-VMDvdDrive -VMName '$VM' -Path '$(win "$ISO")'
    \$dvd = Get-VMDvdDrive -VMName '$VM'
    Set-VMFirmware -VMName '$VM' -FirstBootDevice \$dvd
    Start-VM -Name '$VM'
  "
  cmd_console
}

cmd_seal() {
  vm_exists || die "no VM"
  [ "$(vm_state)" = Off ] || die "shut the VM down first"
  ps "
    Get-VMDvdDrive -VMName '$VM' | Remove-VMDvdDrive
    if ('${1:-}' -eq '--force') { Get-VMCheckpoint -VMName '$VM' -Name vanilla -ErrorAction SilentlyContinue | Remove-VMCheckpoint -Confirm:\$false }
    Checkpoint-VM -Name '$VM' -SnapshotName vanilla
  "
  echo "sealed: checkpoint 'vanilla' taken"
}

cmd_reset() {
  vm_exists || die "no VM"
  [ "$(vm_state)" = Off ] || ps "Stop-VM -Name '$VM' -TurnOff -Force"
  ps "Restore-VMCheckpoint -Name '${1:-vanilla}' -VMName '$VM' -Confirm:\$false"
  echo "restored checkpoint '${1:-vanilla}'"
}

cmd_run()     { vm_exists || die "no VM"; ps "Start-VM -Name '$VM'"; cmd_console; }
cmd_stop()    { ps "Stop-VM -Name '$VM' -Force"; }
cmd_kill()    { ps "Stop-VM -Name '$VM' -TurnOff -Force"; }
cmd_console() { (cd /mnt/c && cmd.exe /c start vmconnect.exe localhost "$VM" >/dev/null 2>&1) || true; }
cmd_status()  { ps "Get-VM -Name '$VM' | Format-Table Name, State, CPUUsage, MemoryAssigned, Uptime -AutoSize"; }

cmd_ip() {
  local ip
  ip="$(ps "
    \$nic = Get-VMNetworkAdapter -VMName '$VM'
    \$ip = \$nic.IPAddresses | Where-Object { \$_ -notmatch ':' } | Select-Object -First 1
    if (-not \$ip) {
      \$mac = \$nic.MacAddress -replace '(..)(?!\$)','\$1-'
      \$ip = (Get-NetNeighbor -LinkLayerAddress \$mac -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
    }
    \$ip
  ")"
  [ -n "$ip" ] || die "no IPv4 yet (VM booted?)"
  echo "$ip"
}

cmd_key() {
  local user="${1:?user}" keydir="$(wslpath -u "$win_home")/.ssh" pub
  mkdir -p "$keydir"
  [ -f "$keydir/id_ed25519" ] || ssh-keygen.exe -q -t ed25519 -N "" -f "$(win "$keydir/id_ed25519")" -C ikigai-vm
  pub="$(tr -d '\r\n' < "$keydir/id_ed25519.pub")"
  "$SSH" $(ssh_opts) "$user@$(cmd_ip)" \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qF '$pub' ~/.ssh/authorized_keys 2>/dev/null || echo '$pub' >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys && echo key installed"
}

cmd_ssh()  { "$SSH" $(ssh_opts) "${1:-root}@$(cmd_ip)"; }

cmd_sync() {
  local user="${1:?user}" dest=".local/share/ikigai" ip
  ip="$(cmd_ip)"
  git -C "$(dirname "$0")/.." ls-files -z --cached --others --exclude-standard \
    | tar --null -T - -czf - \
    | "$SSH" $(ssh_opts) "$user@$ip" "rm -rf $dest && mkdir -p $dest && tar -xzf - -C $dest && echo synced"
}

cmd_snapshot()  { ps "Checkpoint-VM -Name '$VM' -SnapshotName '${1:?name}'"; }
cmd_snapshots() { ps "Get-VMCheckpoint -VMName '$VM' | Format-Table Name, CreationTime -AutoSize"; }

cmd_destroy() {
  vm_exists || die "no VM"
  [ "$(vm_state)" = Off ] || ps "Stop-VM -Name '$VM' -TurnOff -Force"
  ps "Remove-VM -Name '$VM' -Force"
  rm -f "$VHDX"
  echo "destroyed VM '$VM' and $VHDX"
}

usage() {
  cat <<USAGE
usage: vm.sh <command>
  fetch              download + verify Arch ISO
  create             create Gen2 Hyper-V VM + ${DISK_SIZE} VHDX
  install            attach ISO, boot it, open console
  seal [--force]     eject ISO, take 'vanilla' checkpoint (VM must be off); --force replaces an existing one
  reset [name]       roll back to checkpoint (default: vanilla)
  run                start VM + open console
  stop | kill        graceful shutdown | hard power off
  console            open vmconnect window
  status             VM state
  ip                 guest IPv4
  key <user>         install a host ssh key in the VM (do this before sync)
  ssh [user]         ssh into the VM
  sync <user>        copy this working tree into the VM at ~/.local/share/ikigai
  snapshot <name>    take a checkpoint (e.g. phase1)
  snapshots          list checkpoints
  destroy            remove VM and disk
env: VM_SSH=$SSH VM_NAME=$VM VM_CPUS=$CPUS VM_MEM=$MEM VM_DISK=$DISK_SIZE VM_SWITCH='$SWITCH'
VM dir: $VM_DIR
USAGE
}

case "${1:-}" in
  fetch|create|install|run|stop|kill|console|status|ip|snapshots|destroy) "cmd_$1" ;;
  reset|ssh|sync|snapshot|seal|key) "cmd_$1" "${2:-}" ;;
  *) usage; exit 1 ;;
esac
