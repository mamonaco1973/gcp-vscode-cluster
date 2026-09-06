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
  default     = "vscode-vpc"
}

variable "subnet_name" {
  description = "Name of the existing subnetwork"
  type        = string
  default     = "vscode-subnet"
}


# ==============================================================================
# Input Variables: Packer Image
# ------------------------------------------------------------------------------
# Purpose:
#   - Accept name of Packer-built VS Code image
#   - Lookup image metadata dynamically in GCP
# ==============================================================================

variable "vscode_image_name" {
  description = "Name of the Packer-built VS Code image"
  type        = string
}

data "google_compute_image" "vscode_packer_image" {
  name    = var.vscode_image_name        # Image name provided by variable
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
  description = "AD DNS zone / domain (e.g., vscode.mikecloud.com)"
  type        = string
  default     = "vscode.mikecloud.com"
}

variable "realm" {
  description = "Kerberos realm (usually DNS zone in UPPERCASE)"
  type        = string
  default     = "VSCODE.MIKECLOUD.COM"
}

variable "netbios" {
  description = "NetBIOS short domain name (e.g., VSCODE)"
  type        = string
  default     = "VSCODE"
}

variable "user_base_dn" {
  description = "User base DN (e.g., CN=Users,DC=vscode,DC=mikecloud,DC=com)"
  type        = string
  default     = "CN=Users,DC=vscode,DC=mikecloud,DC=com"
}