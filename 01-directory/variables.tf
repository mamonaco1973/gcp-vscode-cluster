# ==============================================================================
# Active Directory Naming Inputs
# ------------------------------------------------------------------------------
# Purpose:
#   - Define DNS, Kerberos, and NetBIOS domain identity values
#   - Provide LDAP base DN configuration
# ==============================================================================


# ==============================================================================
# Variable: dns_zone
# ------------------------------------------------------------------------------
# AD DNS zone / domain (FQDN)
# Used by Samba AD DC for DNS namespace and identity
# ==============================================================================

variable "dns_zone" {
  description = "AD DNS zone / domain (e.g., rstudio.mikecloud.com)"
  type        = string
  default     = "rstudio.mikecloud.com"
}


# ==============================================================================
# Variable: realm
# ------------------------------------------------------------------------------
# Kerberos realm (uppercase DNS zone)
# Convention: match dns_zone in UPPERCASE
# ==============================================================================

variable "realm" {
  description = "Kerberos realm (usually DNS zone in UPPERCASE)"
  type        = string
  default     = "RSTUDIO.MIKECLOUD.COM"
}


# ==============================================================================
# Variable: netbios
# ------------------------------------------------------------------------------
# NetBIOS short domain name
# Typically <= 15 chars; used by legacy clients and SMB flows
# ==============================================================================

variable "netbios" {
  description = "NetBIOS short domain name (e.g., RSTUDIO)"
  type        = string
  default     = "RSTUDIO"
}


# ==============================================================================
# Variable: user_base_dn
# ------------------------------------------------------------------------------
# Base DN for LDAP user accounts
# ==============================================================================

variable "user_base_dn" {
  description = "User base DN (e.g., CN=Users,DC=rstudio,DC=mikecloud,DC=com)"
  type        = string
  default     = "CN=Users,DC=rstudio,DC=mikecloud,DC=com"
}


# ==============================================================================
# Variable: zone
# ------------------------------------------------------------------------------
# GCP zone for deployment
# ==============================================================================

variable "zone" {
  description = "GCP zone (e.g., us-central1-a)"
  type        = string
  default     = "us-central1-a"
}


# ==============================================================================
# Variable: machine_type
# ------------------------------------------------------------------------------
# Machine type for mini AD instance
# ==============================================================================

variable "machine_type" {
  description = "Machine type for mini AD instance (minimum e2-small)"
  type        = string
  default     = "e2-medium"
}


# ==============================================================================
# Variable: vpc
# ------------------------------------------------------------------------------
# VPC network name for mini AD instance
# ==============================================================================

variable "vpc" {
  description = "Network for mini AD instance (e.g., rstudio-vpc)"
  type        = string
  default     = "rstudio-vpc"
}


# ==============================================================================
# Variable: subnet
# ------------------------------------------------------------------------------
# Subnet name for mini AD placement
# ==============================================================================

variable "subnet" {
  description = "Sub-network for mini AD instance (e.g., rstudio-subnet)"
  type        = string
  default     = "rstudio-subnet"
}