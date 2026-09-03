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
# Host-key checking is off on purpose: this only ever talks to the throwaway VM.
SSH=${VM_SSH:-ssh.exe}
SSH_KEY="$(wslpath -u "$win_home")/.ssh/ikigai-vm"
SSH_OPTS=(-i "$(win "$SSH_KEY")" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR)
ARCH_RELEASE_KEY=3E80CA1A8B89F69CBA57D98A76A5EF9054449A5C

vm_exists() { ps "Get-VM -Name '$VM' -ErrorAction SilentlyContinue | Out-Null; \$?" | grep -q True; }
vm_state()  { ps "(Get-VM -Name '$VM').State"; }

cmd_fetch() {
  mkdir -p "$VM_DIR"
  curl -fL --progress-bar -o "$ISO" "$ISO_MIRROR/archlinux-x86_64.iso"
  curl -fsSL -o "$ISO.sig" "$ISO_MIRROR/archlinux-x86_64.iso.sig"
  gpg --auto-key-locate clear,wkd -v --locate-external-key pierre@archlinux.org >/dev/null 2>&1
  gpg --status-fd 1 --verify "$ISO.sig" "$ISO" 2>/dev/null | grep -q "VALIDSIG $ARCH_RELEASE_KEY" \
    || die "ISO signature verification failed (expected Arch release key $ARCH_RELEASE_KEY)"
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
    if (-not (Get-VMDvdDrive -VMName '$VM')) { Add-VMDvdDrive -VMName '$VM' -Path '$(win "$ISO")' }
    \$dvd = Get-VMDvdDrive -VMName '$VM' | Select-Object -First 1
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
  local user="${1:?user}" pub
  mkdir -p "$(dirname "$SSH_KEY")"
  [ -f "$SSH_KEY" ] || ssh-keygen.exe -q -t ed25519 -N "" -f "$(win "$SSH_KEY")" -C ikigai-vm
  pub="$(tr -d '\r\n' < "$SSH_KEY.pub")"
  "$SSH" "${SSH_OPTS[@]}" "$user@$(cmd_ip)" \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qF '$pub' ~/.ssh/authorized_keys 2>/dev/null || echo '$pub' >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys && echo key installed"
}

cmd_ssh()  { "$SSH" "${SSH_OPTS[@]}" "${1:-root}@$(cmd_ip)"; }

cmd_sync() {
  local user="${1:?user}" dest=".local/share/ikigai" ip
  ip="$(cmd_ip)"
  git -C "$(dirname "$0")/.." ls-files -z --cached --others --exclude-standard \
    | tar --null -T - -czf - \
    | "$SSH" "${SSH_OPTS[@]}" "$user@$ip" "keep=\$(mktemp -d); [ -d $dest/tools ] && find $dest/tools -maxdepth 2 -name target -type d -exec cp -a --parents {} \$keep \\; ; rm -rf $dest && mkdir -p $dest && tar -xzf - -C $dest && cp -a \$keep/$dest/tools/. $dest/tools/ 2>/dev/null; rm -rf \$keep; echo synced"
}

# Hyper-V's thumbnail API hands back raw RGB565 at any requested size; ask for the
# guest's current mode and let .NET turn it into a PNG on the host side.
cmd_screenshot() {
  local out="${1:-$VM_DIR/$VM.png}"
  vm_exists || die "no VM"
  [ "$(vm_state)" = Running ] || die "VM is not running"
  ps "
    Add-Type -AssemblyName System.Drawing
    \$vm  = Get-CimInstance -Namespace root\virtualization\v2 -ClassName Msvm_ComputerSystem -Filter \"ElementName='$VM'\"
    \$svc = Get-CimInstance -Namespace root\virtualization\v2 -ClassName Msvm_VirtualSystemManagementService
    \$vsd = Get-CimAssociatedInstance -InputObject \$vm -ResultClassName Msvm_VirtualSystemSettingData | Where-Object { \$_.VirtualSystemType -eq 'Microsoft:Hyper-V:System:Realized' }
    \$head = Get-CimAssociatedInstance -InputObject \$vm -ResultClassName Msvm_VideoHead | Select-Object -First 1
    \$w = [int]\$head.CurrentHorizontalResolution; \$h = [int]\$head.CurrentVerticalResolution
    \$r = Invoke-CimMethod -InputObject \$svc -MethodName GetVirtualSystemThumbnailImage -Arguments @{ TargetSystem = \$vsd; WidthPixels = \$w; HeightPixels = \$h }
    if (\$r.ReturnValue -ne 0) { throw \"GetVirtualSystemThumbnailImage returned \$(\$r.ReturnValue)\" }
    \$bmp = New-Object System.Drawing.Bitmap \$w, \$h, ([System.Drawing.Imaging.PixelFormat]::Format16bppRgb565)
    \$bits = \$bmp.LockBits((New-Object System.Drawing.Rectangle 0, 0, \$w, \$h), 'WriteOnly', \$bmp.PixelFormat)
    [System.Runtime.InteropServices.Marshal]::Copy([byte[]]\$r.ImageData, 0, \$bits.Scan0, \$w * \$h * 2)
    \$bmp.UnlockBits(\$bits)
    \$bmp.Save('$(win "$out")', [System.Drawing.Imaging.ImageFormat]::Png)
    \"\${w}x\${h}\"
  " | sed "s|^|screenshot: $out (|; s|\$|)|"
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
  screenshot [file]  save the guest display as PNG (default: VM dir)
  snapshot <name>    take a checkpoint (e.g. phase1)
  snapshots          list checkpoints
  destroy            remove VM and disk
env: VM_SSH=$SSH VM_NAME=$VM VM_CPUS=$CPUS VM_MEM=$MEM VM_DISK=$DISK_SIZE VM_SWITCH='$SWITCH'
VM dir: $VM_DIR
USAGE
}

case "${1:-}" in
  fetch|create|install|run|stop|kill|console|status|ip|snapshots|destroy) "cmd_$1" ;;
  reset|ssh|sync|snapshot|seal|key|screenshot) "cmd_$1" "${2:-}" ;;
  *) usage; exit 1 ;;
esac
