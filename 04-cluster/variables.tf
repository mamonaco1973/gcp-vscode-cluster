# ==============================================================================
# Input Variables: Network Resources
# ------------------------------------------------------------------------------
# Purpose:
#   - Define existing VPC and subnet names
#   - Enable reuse across environments without hardcoding
# ==============================================================================

variable "vpc_name" {
  description = "Name of the existing VPC network"
  type        = string
  default     = "rstudio-vpc"
}

variable "subnet_name" {
  description = "Name of the existing subnetwork"
  type        = string
  default     = "rstudio-subnet"
}


# ==============================================================================
# Input Variables: Packer Image
# ------------------------------------------------------------------------------
# Purpose:
#   - Accept name of Packer-built RStudio image
#   - Lookup image metadata dynamically in GCP
# ==============================================================================

variable "rstudio_image_name" {
  description = "Name of the Packer-built RStudio image"
  type        = string
}

data "google_compute_image" "rstudio_packer_image" {
  name    = var.rstudio_image_name       # Image name provided by variable
  project = local.credentials.project_id # Use project from decoded credentials
}


# ==============================================================================
# Active Directory Naming Inputs
# ------------------------------------------------------------------------------
# Purpose:
#   - Define DNS, Kerberos, and NetBIOS identity values
#   - Provide LDAP base DN configuration
# ==============================================================================

variable "dns_zone" {
  description = "AD DNS zone / domain (e.g., rstudio.mikecloud.com)"
  type        = string
  default     = "rstudio.mikecloud.com"
}

variable "realm" {
  description = "Kerberos realm (usually DNS zone in UPPERCASE)"
  type        = string
  default     = "RSTUDIO.MIKECLOUD.COM"
}

variable "netbios" {
  description = "NetBIOS short domain name (e.g., RSTUDIO)"
  type        = string
  default     = "RSTUDIO"
}

variable "user_base_dn" {
  description = "User base DN (e.g., CN=Users,DC=rstudio,DC=mikecloud,DC=com)"
  type        = string
  default     = "CN=Users,DC=rstudio,DC=mikecloud,DC=com"
}