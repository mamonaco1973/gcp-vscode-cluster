# ==============================================================================
# accounts.tf
# ------------------------------------------------------------------------------
# Purpose:
#   - Generate AD user passwords.
#   - Store credentials in GCP Secret Manager.
#   - Grant service account access to secrets.
#
# Notes:
#   - Users: admin, jsmith, edavis, rpatel, akumar
#   - Password length: 24 characters
#   - Secrets contain JSON: username, password
# ==============================================================================


# ==============================================================================
# USER: ADMIN
# ------------------------------------------------------------------------------
# Generates password and stores RSTUDIO\admin credentials.
# ==============================================================================

resource "random_password" "admin_password" {
  length           = 24
  special          = true
  override_special = "_."
}

resource "google_secret_manager_secret" "admin_secret" {
  secret_id = "admin-ad-credentials-rstudio"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "admin_secret_version" {
  secret = google_secret_manager_secret.admin_secret.id
  secret_data = jsonencode({
    username = "RSTUDIO\\admin"
    password = random_password.admin_password.result
  })
}


# ==============================================================================
# USER: JOHN SMITH
# ------------------------------------------------------------------------------
# Generates password and stores RSTUDIO\jsmith credentials.
# ==============================================================================

resource "random_password" "jsmith_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "google_secret_manager_secret" "jsmith_secret" {
  secret_id = "jsmith-ad-credentials-rstudio"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "jsmith_secret_version" {
  secret = google_secret_manager_secret.jsmith_secret.id
  secret_data = jsonencode({
    username = "RSTUDIO\\jsmith"
    password = random_password.jsmith_password.result
  })
}


# ==============================================================================
# USER: EMILY DAVIS
# ------------------------------------------------------------------------------
# Generates password and stores RSTUDIO\edavis credentials.
# ==============================================================================

resource "random_password" "edavis_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "google_secret_manager_secret" "edavis_secret" {
  secret_id = "edavis-ad-credentials-rstudio"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "edavis_secret_version" {
  secret = google_secret_manager_secret.edavis_secret.id
  secret_data = jsonencode({
    username = "RSTUDIO\\edavis"
    password = random_password.edavis_password.result
  })
}


# ==============================================================================
# USER: RAJ PATEL
# ------------------------------------------------------------------------------
# Generates password and stores RSTUDIO\rpatel credentials.
# ==============================================================================

resource "random_password" "rpatel_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "google_secret_manager_secret" "rpatel_secret" {
  secret_id = "rpatel-ad-credentials-rstudio"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "rpatel_secret_version" {
  secret = google_secret_manager_secret.rpatel_secret.id
  secret_data = jsonencode({
    username = "RSTUDIO\\rpatel"
    password = random_password.rpatel_password.result
  })
}


# ==============================================================================
# USER: AMIT KUMAR
# ------------------------------------------------------------------------------
# Generates password and stores RSTUDIO\akumar credentials.
# ==============================================================================

resource "random_password" "akumar_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "google_secret_manager_secret" "akumar_secret" {
  secret_id = "akumar-ad-credentials-rstudio"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "akumar_secret_version" {
  secret = google_secret_manager_secret.akumar_secret.id
  secret_data = jsonencode({
    username = "RSTUDIO\\akumar"
    password = random_password.akumar_password.result
  })
}


# ==============================================================================
# LOCALS: SECRET LIST
# ------------------------------------------------------------------------------
# Aggregates all secret IDs for IAM binding.
# ==============================================================================

locals {
  secrets = [
    google_secret_manager_secret.jsmith_secret.secret_id,
    google_secret_manager_secret.edavis_secret.secret_id,
    google_secret_manager_secret.rpatel_secret.secret_id,
    google_secret_manager_secret.akumar_secret.secret_id,
    google_secret_manager_secret.admin_secret.secret_id
  ]
}


# ==============================================================================
# IAM BINDING: SECRET ACCESS
# ------------------------------------------------------------------------------
# Grants roles/secretmanager.secretAccessor to service account.
# ==============================================================================

resource "google_secret_manager_secret_iam_binding" "secret_access" {
  for_each  = toset(local.secrets)
  secret_id = each.key
  role      = "roles/secretmanager.secretAccessor"

  members = [
    "serviceAccount:${local.service_account_email}"
  ]
}