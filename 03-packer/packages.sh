#!/bin/bash
set -euo pipefail
# ---------------------------------------------------------------------------------
# Update OS and Install Required Packages
# ---------------------------------------------------------------------------------
# Refresh package metadata
apt-get update -y

# Prevent interactive prompts during package installs
export DEBIAN_FRONTEND=noninteractive

# Install packages needed for:
#   - Active Directory integration: realmd, sssd-ad, adcli, krb5-user
#   - NSS/PAM integration: libnss-sss, libpam-sss, winbind, libpam-winbind, libnss-winbind
#   - Samba file services: samba, samba-common-bin, samba-libs
#   - Home directory automation: oddjob, oddjob-mkhomedir
#   - Utilities: less, unzip, nano, vim, nfs-common, stunnel4

echo "=== Phase 1: Base utilities and AD join tools ==="  

apt-get install -y less unzip realmd sssd-ad sssd-tools libnss-sss \
    libpam-sss adcli samba-common-bin samba-libs oddjob \
    oddjob-mkhomedir packagekit krb5-user nano vim stunnel4 \
    nfs-common  

echo "=== Phase 2: Build chain ==="
# Kept because VS Code extensions routinely compile native modules on
# install. The R/spatial/HDF5 stacks the RStudio image carried are gone --
# nothing in this build links against them, and they cost several minutes
# per image build.
apt-get install -y build-essential python3-pip python3-venv python3-dev \
    libxml2-dev libcurl4-openssl-dev libssl-dev cmake git

echo "=== Phase 3: Clean up ==="  
apt-get autoremove -y  
apt-get clean  

echo "=== Package installation completed successfully ==="   



