# ==============================================================================
# Custom VPC, Subnet, Router, and NAT for AD Environment
# ------------------------------------------------------------------------------
# Purpose:
#   - Create custom-mode VPC (no auto subnets)
#   - Define dedicated subnet for AD resources
#   - Provision Cloud Router
#   - Provide outbound internet via Cloud NAT
# ==============================================================================


# ==============================================================================
# VPC Network: Active Directory VPC
# ------------------------------------------------------------------------------
# Purpose:
#   - Create custom VPC
#   - Disable automatic subnet creation
# ==============================================================================

resource "google_compute_network" "ad_vpc" {
  name                    = var.vpc
  auto_create_subnetworks = false
}


# ==============================================================================
# Subnet: Active Directory Subnet
# ------------------------------------------------------------------------------
# Purpose:
#   - Define subnet for AD resources
#   - Region: us-central1
#   - CIDR: 10.1.0.0/24
# ==============================================================================

resource "google_compute_subnetwork" "ad_subnet" {
  name          = var.subnet
  region        = "us-central1"
  network       = google_compute_network.ad_vpc.id
  ip_cidr_range = "10.1.0.0/24"
}


# ==============================================================================
# Cloud Router
# ------------------------------------------------------------------------------
# Purpose:
#   - Required for Cloud NAT
#   - Enables dynamic routing features
# ==============================================================================

resource "google_compute_router" "ad_router" {
  name    = "rstudio-router"
  network = google_compute_network.ad_vpc.id
  region  = "us-central1"
}


# ==============================================================================
# Cloud NAT
# ------------------------------------------------------------------------------
# Purpose:
#   - Provide outbound internet for private VMs
#   - Allocate NAT IPs automatically
#   - Enable flow logging (ALL)
# ==============================================================================

resource "google_compute_router_nat" "ad_nat" {
  name   = "rstudio-nat"
  router = google_compute_router.ad_router.name
  region = google_compute_router.ad_router.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ALL"
  }
}