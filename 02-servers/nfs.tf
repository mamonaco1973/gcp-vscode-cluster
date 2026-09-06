# ==============================================================================
# Google Cloud Filestore (Basic NFS) and Firewall
# ------------------------------------------------------------------------------
# Purpose:
#   - Provision Filestore instance for NFS storage
#   - Secure access with firewall rule on port 2049
#
# Notes:
#   - Basic tiers support NFSv3 only
#   - Minimum size for Basic = 1024 GiB (1 TB)
#   - 0.0.0.0/0 used for lab only; restrict in production
# ==============================================================================

resource "google_filestore_instance" "nfs_server" {

  # Filestore Configuration
  # - Tier controls performance and pricing
  # - Location must be zonal (e.g., us-central1-b)
  name     = "rstudio-nfs-server"
  tier     = "BASIC_HDD"     # Basic HDD (NFSv3)
  location = "us-central1-b" # Zonal deployment
  project  = local.credentials.project_id

  # File Share Configuration
  # - Minimum capacity for Basic = 1024 GiB
  file_shares {
    capacity_gb = 1024       # 1 TB minimum
    name        = "filestore"

    nfs_export_options {
      access_mode = "READ_WRITE"     # Read/write access
      squash_mode = "NO_ROOT_SQUASH" # Preserve root privileges
      ip_ranges   = ["0.0.0.0/0"]    # Lab only; restrict in production
    }
  }

  # Network Attachment
  networks {
    network = data.google_compute_network.ad_vpc.name # Attach to AD VPC
    modes   = ["MODE_IPV4"]                           # IPv4 mode
  }
}


# ==============================================================================
# Firewall Rule: Allow NFS Traffic
# ------------------------------------------------------------------------------
# Purpose:
#   - Allow inbound NFS (2049) over TCP and UDP
#   - Required for Linux clients mounting Filestore
# ==============================================================================

resource "google_compute_firewall" "allow_nfs" {
  name    = "rstudio-allow-nfs"
  network = data.google_compute_network.ad_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }

  allow {
    protocol = "udp"
    ports    = ["2049"]
  }

  source_ranges = ["0.0.0.0/0"] # Lab only; restrict to subnet in production
}


# ==============================================================================
# Output: Filestore IP Address (Optional)
# ------------------------------------------------------------------------------
# Purpose:
#   - Expose private IP for mount commands
#   - Example: <IP_ADDRESS>:/filestore
# ==============================================================================

# output "filestore_ip" {
#   value = google_filestore_instance.nfs_server.networks[0].ip_addresses[0]
# }