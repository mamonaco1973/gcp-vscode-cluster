#!/bin/bash
set -euo pipefail

LOG=/root/boot.log
mkdir -p /root
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG" | logger -t startup-script -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR

FLAG_FILE="/root/.vscode_provisioned"

# Prevent infinite loop
if [ -f "$FLAG_FILE" ]; then
  echo "Provisioning already completed — skipping."
  exit 0
fi

# Mount NFS file system
mkdir -p /nfs
echo "${nfs_server_ip}:/filestore /nfs nfs vers=3,rw,hard,noatime,rsize=65536,wsize=65536,timeo=600,_netdev 0 0" \
| sudo tee -a /etc/fstab
systemctl daemon-reload
mount /nfs
# /nfs/extensions is the shared VSIX staging area -- extensions that are
# not on Open VSX are dropped there as files and installed from disk.
mkdir -p /nfs/home /nfs/data /nfs/extensions

# Map /home to NFS
echo "${nfs_server_ip}:/filestore/home /home nfs vers=3,rw,hard,noatime,rsize=65536,wsize=65536,timeo=600,_netdev 0 0" \
| sudo tee -a /etc/fstab
systemctl daemon-reload
mount /home

# Join Active Directory domain
secretValue=$(gcloud secrets versions access latest --secret="admin-ad-credentials-vscode")
admin_password=$(echo $secretValue | jq -r '.password')
admin_username=$(echo $secretValue | jq -r '.username' | sed 's/.*\\//')
echo -e "$admin_password" | sudo /usr/sbin/realm join -U "$admin_username" \
    ${domain_fqdn} --verbose

# Enable password authentication for AD users
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' \
    /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# Configure SSSD for AD integration
sudo sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|' \
    /etc/sssd/sssd.conf
sudo sed -i 's/^access_provider = ad$/access_provider = simple\nsimple_allow_groups = ${force_group}/' /etc/sssd/sssd.conf

# Prevent XAuthority warnings for new AD users
ln -s /nfs /etc/skel/nfs
touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

# Enable home directory creation and restart services
sudo pam-auth-update --enable mkhomedir
sudo systemctl restart ssh
sudo systemctl restart sssd

# Grant sudo privileges to AD admin group
echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/10-linux-admins

# Enforce home directory permissions
sudo sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

# ------------------------------------------------------------------------------
# Session broker
# ------------------------------------------------------------------------------
# Per-user editor state (SQLite) stays on instance-local disk. Filestore is
# NFSv3 and SQLite over NFS is the classic corruption case -- only user FILES
# belong on the share. Cost: editor layout is lost when a node is replaced.
mkdir -p /var/lib/vscode
chmod 0751 /var/lib/vscode

cat <<EOF | sudo tee /etc/vscode-broker.env > /dev/null
BROKER_PORT=8080
REQUIRED_GROUP=${force_group}
SESSION_IDLE_MINUTES=120
PORT_RANGE_START=9000
PORT_RANGE_END=9500
VSCODE_STATE_ROOT=/var/lib/vscode
EOF

# Written before the broker starts, not after. Everything above this line is
# one-shot and survives a reboot on its own -- the mounts are in /etc/fstab
# and the domain join is on disk. If the broker fails to come up, a reboot
# must NOT re-run realm join against an already-joined machine.
uptime
touch "$FLAG_FILE"

# Enabled only now that SSSD can resolve AD users. Enabling it in the image
# would let the load balancer mark the node healthy before any login could
# possibly succeed.
sudo systemctl enable vscode-broker
sudo systemctl restart vscode-broker