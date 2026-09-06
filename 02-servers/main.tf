# ==============================================================================
# Google Cloud Provider & Local Variables
# ------------------------------------------------------------------------------
# Purpose:
#   - Configure Google provider using service account JSON
#   - Decode credentials for reuse across module resources
# ==============================================================================

provider "google" {
  project     = local.credentials.project_id      # Project ID from credentials JSON
  credentials = file("../credentials.json")       # Path to service account JSON file
}


# ==============================================================================
# Local Variables
# ------------------------------------------------------------------------------
# Purpose:
#   - Decode credentials JSON once
#   - Expose service account email for IAM bindings
# ==============================================================================

locals {
  credentials           = jsondecode(file("../credentials.json")) # Decoded JSON map
  service_account_email = local.credentials.client_email          # Service account identity
}


# ==============================================================================
# Data Sources: Network and Subnet
# ------------------------------------------------------------------------------
# Purpose:
#   - Lookup existing VPC and subnet
#   - Attach resources to AD lab networking
# ==============================================================================

data "google_compute_network" "ad_vpc" {
  name = var.vpc  # VPC name for AD resources
}

data "google_compute_subnetwork" "ad_subnet" {
  name   = var.subnet     # Subnet name for AD placement
  region = "us-central1"  # Deployment region
}