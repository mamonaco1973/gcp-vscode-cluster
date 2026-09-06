# ==============================================================================
# Google Cloud Provider Configuration
# ------------------------------------------------------------------------------
# Purpose:
#   - Configure Terraform to interact with Google Cloud
#   - Authenticate using local service account JSON
#   - Target correct GCP project for resource provisioning
# ==============================================================================

provider "google" {
  project     = local.credentials.project_id
  credentials = file("../credentials.json")
}


# ==============================================================================
# Local Variables: Credentials Parsing
# ------------------------------------------------------------------------------
# Purpose:
#   - Decode service account credentials JSON
#   - Expose project ID and service account email for reuse
# ==============================================================================

locals {
  credentials           = jsondecode(file("../credentials.json"))
  service_account_email = local.credentials.client_email
}


# ==============================================================================
# Data Sources: Existing Network Infrastructure
# ------------------------------------------------------------------------------
# Purpose:
#   - Lookup existing VPC and subnet by variable name
#   - Integrate new resources with predefined networking
# ==============================================================================

data "google_compute_network" "ad_vpc" {
  name = var.vpc_name
}

data "google_compute_subnetwork" "ad_subnet" {
  name   = var.subnet_name
  region = "us-central1"
}


# ==============================================================================
# Data Source: Existing Filestore Instance
# ------------------------------------------------------------------------------
# Purpose:
#   - Retrieve existing Filestore NFS instance details
#   - Reference IP and attributes in startup scripts or mounts
# ==============================================================================

data "google_filestore_instance" "nfs_server" {
  name     = "rstudio-nfs-server"
  location = "us-central1-b"
  project  = local.credentials.project_id
}