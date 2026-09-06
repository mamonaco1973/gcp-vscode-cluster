# ==============================================================================
# Google Cloud Provider Configuration
# ------------------------------------------------------------------------------
# Purpose:
#   - Configure Google provider for Terraform
#   - Load service account credentials from external JSON
# ==============================================================================

provider "google" {
  project     = local.credentials.project_id      # Project ID from credentials JSON
  credentials = file("../credentials.json")       # Path to service account JSON file
}


# ==============================================================================
# Local Variables
# ------------------------------------------------------------------------------
# Purpose:
#   - Decode credentials file once
#   - Expose service account email for reuse across modules
# ==============================================================================

locals {
  credentials           = jsondecode(file("../credentials.json")) # Decoded JSON map
  service_account_email = local.credentials.client_email          # Service account identity
}