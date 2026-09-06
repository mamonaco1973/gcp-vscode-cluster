# ==============================================================================
# Random String, Firewall, and Ubuntu VM for AD/NFS Gateway
# ------------------------------------------------------------------------------
# Purpose:
#   - Generate random suffix for unique resource names
#   - Allow inbound SSH (22) and SMB (445) to tagged instances
#   - Deploy Ubuntu VM for NFS gateway and AD join client
#   - Lookup latest Ubuntu 24.04 LTS image
#
# Notes:
#   - source_ranges 0.0.0.0/0 is lab-only; restrict for production
# ==============================================================================


# ==============================================================================
# Random String Generator
# ------------------------------------------------------------------------------
# Purpose:
#   - Generate 6-character lowercase suffix for unique names
# ==============================================================================

resource "random_string" "vm_suffix" {
  length  = 6     # Generated string length
  special = false # DNS-friendly (no special chars)
  upper   = false # Lowercase only
}


# ==============================================================================
# Firewall Rule: Allow SSH
# ------------------------------------------------------------------------------
# Purpose:
#   - Allow inbound TCP/22 to instances tagged allow-ssh
# ==============================================================================

resource "google_compute_firewall" "allow_ssh" {
  name    = "rstudio-allow-ssh"
  network = var.vpc

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["rstudio-allow-ssh"] # Applies to instances with allow-ssh tag
  source_ranges = ["0.0.0.0/0"] # Lab only; restrict for production
}


# ==============================================================================
# Firewall Rule: Allow SMB
# ------------------------------------------------------------------------------
# Purpose:
#   - Allow inbound TCP/445 to instances tagged allow-smb
# ==============================================================================

resource "google_compute_firewall" "allow_smb" {
  name    = "rstudio-allow-smb"
  network = var.vpc

  allow {
    protocol = "tcp"
    ports    = ["445"]
  }

  target_tags = ["rstudio-allow-smb"] # Applies to instances with allow-smb tag
  source_ranges = ["0.0.0.0/0"] # Lab only; restrict for production
}


# ==============================================================================
# Ubuntu VM: NFS Gateway + AD Join Client
# ------------------------------------------------------------------------------
# Purpose:
#   - Deploy Ubuntu 24.04 VM in ad-vpc/ad-subnet
#   - Run startup script to join AD and mount Filestore NFS
#   - Enable OS Login for SSH
# ==============================================================================

resource "google_compute_instance" "nfs_gateway_instance" {
  name         = "nfs-gateway-${random_string.vm_suffix.result}"
  machine_type = "e2-standard-2"
  zone         = "us-central1-a"

  # Boot Disk
  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_latest.self_link
    }
  }

  # Network Interface
  network_interface {
    network    = var.vpc
    subnetwork = var.subnet

    # Ephemeral public IP (required for SSH access)
    access_config {}
  }

  # Metadata (OS Login + Startup Script)
  metadata = {
    enable-oslogin = "TRUE" # Enforce OS Login

    startup-script = templatefile("./scripts/nfs_gateway_init.sh", {
      domain_fqdn   = "rstudio.mikecloud.com"
      nfs_server_ip = google_filestore_instance.nfs_server.networks[0].ip_addresses[0]
      domain_fqdn   = var.dns_zone
      netbios       = var.netbios
      force_group   = "rstudio-users"
      realm         = var.realm
    })
  }

  # Service Account
  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Firewall Tags
  tags = ["rstudio-allow-ssh", "rstudio-allow-nfs", "rstudio-allow-smb"] # SSH + NFS + SMB rules
}


# ==============================================================================
# Data Source: Latest Ubuntu 24.04 LTS Image
# ------------------------------------------------------------------------------
# Purpose:
#   - Fetch latest Ubuntu 24.04 LTS image from ubuntu-os-cloud
# ==============================================================================

data "google_compute_image" "ubuntu_latest" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}