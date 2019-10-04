#!/usr/bin/env bash

set -euo pipefail

log() {
    printf "[%s] %s\n" "$(date)" "$@"
}

# Update this list if you add or remove VMs from the Vagrantfile.
VM_IPs=("192.168.33.2" "192.168.33.3")

log "Creating VMs..."
vagrant up

log "Adding host keys to known_hosts and setting up firewalls..."
for ip in "${VM_IPs[@]}"; do
    ssh-keyscan -H "$ip" >> ~/.ssh/known_hosts
    ssh racket@"$ip" <<EOF
sudo ufw default allow
yes | sudo ufw enable
sudo ufw default deny outgoing
sudo ufw default deny incoming
sudo ufw allow OpenSSH
sudo ufw status
EOF
done

log "Collecting VM ids..."
VMs=$(vagrant status | grep pkg-build | awk '{print $1}')

log "Creating VM snapshots..."
for vm in $VMs; do
    vboxmanage snapshot "$vm" take init
done

log "Halting all the VMs..."
for vm in $VMs; do
    vboxmanage controlvm "$vm" poweroff
done
