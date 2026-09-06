# ==============================================================================
# Instance Template: RStudio VM
# ------------------------------------------------------------------------------
# Purpose:
#   - Define VM template for RStudio instances
#   - Specify machine type, disk, network, and service account
#   - Used by managed instance group for consistent deployments
# ==============================================================================

resource "google_compute_instance_template" "rstudio_template" {
  name         = "rstudio-template" # Template name
  machine_type = "e2-standard-2"    # 2 vCPU, 8 GB RAM

  tags = ["allow-rstudio"] # Used by firewall rules

  # Disk Configuration
  disk {
    auto_delete  = true # Delete disk with instance
    boot         = true # Mark as boot disk
    source_image = data.google_compute_image.rstudio_packer_image.self_link
  }

  # Network Configuration
  network_interface {
    network    = data.google_compute_network.ad_vpc.id
    subnetwork = data.google_compute_subnetwork.ad_subnet.id
  }

  # Service Account
  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Startup Script
  metadata_startup_script = templatefile("./scripts/rstudio_booter.sh", {
    nfs_server_ip = data.google_filestore_instance.nfs_server.networks[0].ip_addresses[0]
    domain_fqdn   = var.dns_zone
    force_group   = "rstudio-users"
  })
}


# ==============================================================================
# Regional Managed Instance Group
# ------------------------------------------------------------------------------
# Purpose:
#   - Manage RStudio instances based on template
#   - Provide scaling and auto-healing capabilities
# ==============================================================================

resource "google_compute_region_instance_group_manager" "instance_group_manager" {
  name               = "rstudio-instance-group"
  base_instance_name = "rstudio"
  target_size        = 2
  region             = "us-central1"

  version {
    instance_template = google_compute_instance_template.rstudio_template.self_link
  }

  named_port {
    name = "http"
    port = 8787
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http_health_check.self_link
    initial_delay_sec = 300
  }
}


# ==============================================================================
# Regional Autoscaler
# ------------------------------------------------------------------------------
# Purpose:
#   - Scale instance group based on CPU utilization
#   - Maintain defined min and max replica bounds
# ==============================================================================

resource "google_compute_region_autoscaler" "autoscaler" {
  name   = "rstudio-autoscaler"
  target = google_compute_region_instance_group_manager.instance_group_manager.self_link
  region = "us-central1"

  autoscaling_policy {
    max_replicas    = 4   # Upper bound
    min_replicas    = 2   # Lower bound
    cooldown_period = 300 # Delay between scale actions

    cpu_utilization {
      target = 0.6 # Scale at 60% CPU
    }
  }
}


# ==============================================================================
# Firewall Rule: Allow RStudio (Web + SSH)
# ------------------------------------------------------------------------------
# Purpose:
#   - Allow TCP 8787 (RStudio), 22 (SSH), and 80 (HTTP)
#   - Apply only to instances tagged allow-rstudio
#   - 0.0.0.0/0 used for lab only; restrict in production
# ==============================================================================

resource "google_compute_firewall" "allow_rstudio" {
  name    = "allow-rstudio"
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["8787", "22", "80"]
  }

  target_tags   = ["allow-rstudio"]
  source_ranges = ["0.0.0.0/0"]
}


# ==============================================================================
# Health Check: RStudio Service
# ------------------------------------------------------------------------------
# Purpose:
#   - Monitor instance health for managed group
#   - Mark instances healthy/unhealthy via HTTP checks
# ==============================================================================

resource "google_compute_health_check" "http_health_check" {
  name                = "http-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    request_path = "/auth-sign-in"
    port         = 8787
  }
}