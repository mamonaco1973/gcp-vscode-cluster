#!/bin/bash
set -euo pipefail

LOG=/root/boot.log
mkdir -p /root
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG" | logger -t startup-script -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR

FLAG_FILE="/root/.rstudio_provisioned"

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
mkdir -p /nfs/home /nfs/data /nfs/rlibs

# Map /home to NFS
echo "${nfs_server_ip}:/filestore/home /home nfs vers=3,rw,hard,noatime,rsize=65536,wsize=65536,timeo=600,_netdev 0 0" \
| sudo tee -a /etc/fstab
systemctl daemon-reload
mount /home

# Join Active Directory domain
secretValue=$(gcloud secrets versions access latest --secret="admin-ad-credentials-rstudio")
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
sudo systemctl restart rstudio-server
sudo systemctl enable rstudio-server

# Grant sudo privileges to AD admin group
echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/10-linux-admins

# Enforce home directory permissions
sudo sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

# Configure R library paths
cat <<'EOF' | sudo tee /usr/lib/R/etc/Rprofile.site > /dev/null
local({
  userlib <- Sys.getenv("R_LIBS_USER")
  if (!dir.exists(userlib)) {
    dir.create(userlib, recursive = TRUE, showWarnings = FALSE)
  }
  nfs <- "/nfs/rlibs"
  .libPaths(c(userlib, nfs, .libPaths()))
})
EOF

chgrp rstudio-admins /nfs/rlibs

uptime
touch "$FLAG_FILE"