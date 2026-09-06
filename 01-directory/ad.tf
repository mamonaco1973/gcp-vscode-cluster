# ==========================================================================================
# Mini Active Directory (mini-ad) Module Invocation
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Calls the reusable "mini-ad" module to provision an Ubuntu-based AD DC
#   - Passes networking, DNS, and authentication parameters
#   - Supplies user account definitions via rendered JSON
# ==========================================================================================

module "mini_ad" {

  source            = "github.com/mamonaco1973/module-gcp-mini-ad" # Reusable mini-ad module
  netbios           = var.netbios                                  # NetBIOS domain name (e.g., MCLOUD)
  network           = google_compute_network.ad_vpc.id             # VPC where AD resides
  realm             = var.realm                                    # Kerberos realm (UPPERCASE DNS domain)
  users_json        = local.users_json                             # JSON blob of users/passwords
  user_base_dn      = var.user_base_dn                             # Base DN for LDAP user accounts
  ad_admin_password = random_password.admin_password.result        # Randomized AD admin password
  dns_zone          = var.dns_zone                                 # AD-integrated DNS zone
  subnetwork        = google_compute_subnetwork.ad_subnet.id       # Subnet for AD VM
  email             = local.service_account_email                  # Service account email
  machine_type      = var.machine_type                             # Machine type for AD VM

  # Ensure NAT and routing exist before bootstrap (package repos, updates, etc.)
  depends_on = [
    google_compute_subnetwork.ad_subnet,
    google_compute_router.ad_router,
    google_compute_router_nat.ad_nat
  ]
}


# ==========================================================================================
# Local Variable: users_json
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Renders users.json.template into a JSON blob
#   - Injects generated random passwords
#   - Passed to bootstrap for automated user creation
# ==========================================================================================

locals {
  users_json = templatefile("./scripts/users.json.template", {
    USER_BASE_DN    = var.user_base_dn                       # Base DN for LDAP users
    DNS_ZONE        = var.dns_zone                           # AD-integrated DNS zone
    REALM           = var.realm                              # Kerberos realm (uppercase FQDN)
    NETBIOS         = var.netbios                            # NetBIOS domain name
    jsmith_password = random_password.jsmith_password.result # Random password for John Smith
    edavis_password = random_password.edavis_password.result # Random password for Emily Davis
    rpatel_password = random_password.rpatel_password.result # Random password for Raj Patel
    akumar_password = random_password.akumar_password.result # Random password for Amit Kumar
  })
}