#!/usr/bin/env bash
# Arch ships no firewall. Deny incoming, allow outgoing, keep ssh when it is enabled,
# and let ufw-docker close the hole Docker's own iptables rules punch through ufw for
# published ports. Containers may still reach the host's DNS.
set -euo pipefail

sudo ufw default deny incoming
sudo ufw default allow outgoing
if systemctl is-enabled -q sshd 2>/dev/null; then
  sudo ufw allow ssh
fi
sudo ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'docker dns'
sudo ufw allow in proto udp from 192.168.0.0/16 to 172.17.0.1 port 53 comment 'docker dns'

sudo ufw --force enable
sudo ufw-docker install
sudo systemctl enable --now ufw
sudo ufw reload
sudo ufw status verbose | head -5
