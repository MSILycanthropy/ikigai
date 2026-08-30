#!/usr/bin/env bash
# Drive a Windows-hosted QEMU VM from WSL2. Disk + ISO live on the Windows
# side so QEMU reads them natively instead of through the 9P bridge.
set -euo pipefail

QEMU_DIR="/mnt/c/Program Files/qemu"
QEMU="$QEMU_DIR/qemu-system-x86_64.exe"
QEMU_IMG="$QEMU_DIR/qemu-img.exe"

win_home="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
VM_DIR="$(wslpath -u "$win_home")/ikigai-vm"
DISK="$VM_DIR/arch.qcow2"
ISO="$VM_DIR/archlinux-x86_64.iso"
OVMF_CODE="$QEMU_DIR/share/edk2-x86_64-code.fd"
OVMF_VARS="$VM_DIR/efivars.fd"

CPUS=${VM_CPUS:-4}
MEM=${VM_MEM:-4G}
GL=${VM_GL:-1}
AUDIO=${VM_AUDIO:-0}
ACCEL=${VM_ACCEL:-whpx}
SSH_PORT=${VM_SSH_PORT:-2222}
DISK_SIZE=40G
ISO_MIRROR="https://geo.mirror.pkgbuild.com/iso/latest"

win() { wslpath -w "$1"; }
die() { echo "vm.sh: $*" >&2; exit 1; }

need_qemu() { [ -x "$QEMU" ] || die "QEMU not found at $QEMU (winget install SoftwareFreedomConservancy.QEMU)"; }

base_args() {
  [ -f "$OVMF_VARS" ] || { cp "$QEMU_DIR/share/edk2-i386-vars.fd" "$OVMF_VARS"; chmod u+w "$OVMF_VARS"; }
  printf '%s\n' \
    -accel "$ACCEL" -cpu qemu64 -smp "$CPUS" -m "$MEM" \
    -machine q35 \
    -drive "if=pflash,format=raw,readonly=on,file=$(win "$OVMF_CODE")" \
    -drive "if=pflash,format=raw,file=$(win "$OVMF_VARS")" \
    -drive "file=$(win "$DISK"),if=virtio,format=qcow2" \
    -device virtio-net-pci,netdev=n0 -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22" \
    -device virtio-keyboard-pci -device virtio-tablet-pci
  if [ "$GL" = 1 ]; then
    printf '%s\n' -device virtio-vga-gl -display sdl,gl=on
  else
    printf '%s\n' -device virtio-vga -display sdl
  fi
  [ "$AUDIO" = 1 ] && printf '%s\n' -audiodev dsound,id=snd0 -device intel-hda -device hda-output,audiodev=snd0
  return 0
}

cmd_fetch() {
  mkdir -p "$VM_DIR"
  curl -fL --progress-bar -o "$ISO" "$ISO_MIRROR/archlinux-x86_64.iso"
  curl -fsSL -o "$ISO.sig" "$ISO_MIRROR/archlinux-x86_64.iso.sig"
  gpg --auto-key-locate clear,wkd -v --locate-external-key pierre@archlinux.org >/dev/null 2>&1 || true
  gpg --verify "$ISO.sig" "$ISO" || die "ISO signature verification failed"
  echo "fetched + verified $ISO"
}

cmd_create() {
  need_qemu
  mkdir -p "$VM_DIR"
  [ -f "$DISK" ] && die "$DISK already exists; delete it or use restore"
  "$QEMU_IMG" create -f qcow2 "$(win "$DISK")" "$DISK_SIZE"
}

cmd_install() {
  need_qemu
  [ -f "$ISO" ] || die "no ISO; run: vm.sh fetch"
  [ -f "$DISK" ] || die "no disk; run: vm.sh create"
  mapfile -t args < <(base_args)
  "$QEMU" "${args[@]}" -cdrom "$(win "$ISO")" -boot d
}

cmd_run() {
  need_qemu
  [ -f "$DISK" ] || die "no disk; run: vm.sh create && vm.sh install"
  mapfile -t args < <(base_args)
  "$QEMU" "${args[@]}"
}

cmd_snapshot() { need_qemu; "$QEMU_IMG" snapshot -c "${1:?name}" "$(win "$DISK")"; }
cmd_restore()  { need_qemu; "$QEMU_IMG" snapshot -a "${1:?name}" "$(win "$DISK")"; }
cmd_ssh() { ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${1:-root}@localhost"; }
cmd_snapshots() { need_qemu; "$QEMU_IMG" snapshot -l "$(win "$DISK")"; }

usage() {
  cat <<USAGE
usage: vm.sh <command>
  fetch              download + verify Arch ISO
  create             create blank ${DISK_SIZE} disk
  install            boot ISO to do the vanilla Arch install
  run                boot from disk
  snapshot <name>    save disk snapshot (vanilla, aged, ...)
  restore <name>     roll disk back to snapshot
  snapshots          list snapshots
  ssh [user]         ssh into the running VM (port $SSH_PORT)
VM dir: $VM_DIR
USAGE
}

case "${1:-}" in
  fetch|create|install|run|snapshots) "cmd_$1" ;;
  snapshot|restore|ssh) "cmd_$1" "${2:-}" ;;
  *) usage; exit 1 ;;
esac
