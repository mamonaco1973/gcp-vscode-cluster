# ==============================================================================
# SysAdmin Credentials + Windows AD Management VM
# ------------------------------------------------------------------------------
# Purpose:
#   - Generate SysAdmin credentials and store in Secret Manager
#   - Allow inbound RDP (3389) to tagged Windows instances
#   - Deploy Windows Server 2022 AD management VM
#   - Lookup latest Windows Server 2022 image
#
# Notes:
#   - 0.0.0.0/0 is lab-only; restrict in production
# ==============================================================================


# ==============================================================================
# SysAdmin Credentials
# ------------------------------------------------------------------------------
# Purpose:
#   - Generate secure SysAdmin password
#   - Store credentials in GCP Secret Manager
# ==============================================================================

resource "random_password" "sysadmin_password" {
  length           = 24
  special          = true
  override_special = "-_."
}

resource "google_secret_manager_secret" "sysadmin_secret" {
  secret_id = "sysadmin-ad-credentials-rstudio"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "admin_secret_version" {
  secret = google_secret_manager_secret.sysadmin_secret.id
  secret_data = jsonencode({
    username = "sysadmin"
    password = random_password.sysadmin_password.result
  })
}


# ==============================================================================
# Firewall Rule: Allow RDP
# ------------------------------------------------------------------------------
# Purpose:
#   - Allow inbound TCP/3389 to instances tagged allow-rdp
# ==============================================================================

resource "google_compute_firewall" "allow_rdp" {
  name    = "rstudio-allow-rdp"
  network = var.vpc

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  target_tags   = ["rstudio-allow-rdp"] # Applies only to tagged instances
  source_ranges = ["0.0.0.0/0"] # Lab only; restrict for production
}


# ==============================================================================
# Windows AD Management VM
# ------------------------------------------------------------------------------
# Purpose:
#   - Deploy Windows Server 2022 VM for AD administration
#   - Auto-join domain via PowerShell startup script
# ==============================================================================

resource "google_compute_instance" "windows_ad_instance" {
  name         = "win-ad-${random_string.vm_suffix.result}" # Unique name
  machine_type = "e2-standard-2"                            # Balanced size
  zone         = "us-central1-a"

  # Boot Disk (Windows Server 2022)
  boot_disk {
    initialize_params {
      image = data.google_compute_image.windows_2022.self_link
    }
  }

  # Network Interface
  network_interface {
    network    = var.vpc
    subnetwork = var.subnet

    access_config {} # Public IP for RDP access
  }

  # Service Account
  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Startup Script (Domain Join)
  metadata = {
    windows-startup-script-ps1 = templatefile("./scripts/ad_join.ps1", {
      domain_fqdn = "rstudio.mikecloud.com"
      nfs_gateway = google_compute_instance.nfs_gateway_instance.network_interface[0].network_ip
    })

    admin_username = "sysadmin"
    admin_password = random_password.sysadmin_password.result
  }

  # Firewall Tags
  tags = ["rstudio-allow-rdp"] # Applies RDP firewall rule
}


# ==============================================================================
# Data Source: Latest Windows Server 2022 Image
# ------------------------------------------------------------------------------
# Purpose:
#   - Fetch latest Windows Server 2022 image from windows-cloud
# ==============================================================================

data "google_compute_image" "windows_2022" {
  family  = "windows-2022"
  project = "windows-cloud"
}