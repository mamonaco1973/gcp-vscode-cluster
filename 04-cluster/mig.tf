# ==============================================================================
# Instance Template: VS Code VM
# ------------------------------------------------------------------------------
# Purpose:
#   - Define VM template for VS Code instances
#   - Specify machine type, disk, network, and service account
#   - Used by managed instance group for consistent deployments
# ==============================================================================

resource "google_compute_instance_template" "vscode_template" {
  name         = "vscode-template" # Template name
  machine_type = "e2-standard-2"   # 2 vCPU, 8 GB RAM

  tags = ["allow-vscode"] # Used by firewall rules

  # Disk Configuration
  disk {
    auto_delete  = true # Delete disk with instance
    boot         = true # Mark as boot disk
    source_image = data.google_compute_image.vscode_packer_image.self_link
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
  metadata_startup_script = templatefile("./scripts/vscode_booter.sh", {
    nfs_server_ip = data.google_filestore_instance.nfs_server.networks[0].ip_addresses[0]
    domain_fqdn   = var.dns_zone
    force_group   = "vscode-users"
  })
}


# ==============================================================================
# Regional Managed Instance Group
# ------------------------------------------------------------------------------
# Purpose:
#   - Manage VS Code instances based on template
#   - Provide scaling and auto-healing capabilities
# ==============================================================================

resource "google_compute_region_instance_group_manager" "instance_group_manager" {
  name               = "vscode-instance-group"
  base_instance_name = "vscode"
  target_size        = 2
  region             = "us-central1"

  version {
    instance_template = google_compute_instance_template.vscode_template.self_link
  }

  named_port {
    name = "http"
    port = 8080
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
  name   = "vscode-autoscaler"
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
# Firewall Rule: Allow VS Code (Web + SSH)
# ------------------------------------------------------------------------------
# Purpose:
#   - Allow TCP 8080 (session broker) and 22 (SSH)
#   - Apply only to instances tagged allow-vscode
#
# 130.211.0.0/22 and 35.191.0.0/16 are Google's load balancer and health
# check ranges -- without them the backend service marks every node
# UNHEALTHY and the LB serves 502 with no other symptom. They are not
# optional and they are not documented on the resource.
#
# 0.0.0.0/0 covers SSH for lab convenience; restrict it in production.
# ==============================================================================

resource "google_compute_firewall" "allow_vscode" {
  name    = "allow-vscode"
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["8080", "22"]
  }

  target_tags = ["allow-vscode"]

  source_ranges = [
    "130.211.0.0/22", # Google LB
    "35.191.0.0/16",  # Google health checks
    "0.0.0.0/0",      # SSH
  ]
}


# ==============================================================================
# Health Check: VS Code Service
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

  # /healthz answers without a session cookie. Probing / would redirect to
  # the login page, so every healthy node would report a 302.
  http_health_check {
    request_path = "/healthz"
    port         = 8080
  }
}