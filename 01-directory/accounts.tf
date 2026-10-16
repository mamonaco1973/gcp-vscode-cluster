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
#   - admin: a strong 24-character random password (used by automation for
#     the domain join; never typed).
#   - Users: friendly "<word>-<number>" passwords (e.g. orange-481920) so they
#     are easy to type at the VS Code / desktop login during a demo.
#     lower + digit + "-" satisfies AD's 3-of-4 complexity rule.
#   - Secrets contain JSON: username, password
# ==============================================================================


# ==============================================================================
# USER: ADMIN
# ------------------------------------------------------------------------------
# Generates password and stores VSCODE\admin credentials.
# ==============================================================================

resource "random_password" "admin_password" {
  length           = 24
  special          = true
  override_special = "_."
}

resource "google_secret_manager_secret" "admin_secret" {
  secret_id = "admin-ad-credentials-vscode"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "admin_secret_version" {
  secret = google_secret_manager_secret.admin_secret.id
  secret_data = jsonencode({
    username = "VSCODE\\admin"
    password = random_password.admin_password.result
  })
}


# ==============================================================================
# FRIENDLY USER PASSWORDS: "<word>-<number>"
# ==============================================================================

locals {
  word_users = toset(["jsmith", "edavis", "rpatel", "akumar"])

  memorable_words = [
    "bright", "simple", "orange", "window", "little", "people", "friend",
    "yellow", "animal", "family", "circle", "moment", "summer", "button",
    "planet", "rocket", "silver", "forest", "stream", "butter", "castle",
    "wonder", "gentle", "driver", "coffee"
  ]
}

resource "random_shuffle" "word" {
  for_each     = local.word_users
  input        = local.memorable_words
  result_count = 1
}

resource "random_integer" "num" {
  for_each = local.word_users
  min      = 100000
  max      = 999999
}

locals {
  passwords = {
    for user in local.word_users :
    user => format("%s-%d", random_shuffle.word[user].result[0], random_integer.num[user].result)
  }
}


# ==============================================================================
# USER: JOHN SMITH
# ------------------------------------------------------------------------------
# Stores VSCODE\jsmith credentials (friendly password above).
# ==============================================================================

resource "google_secret_manager_secret" "jsmith_secret" {
  secret_id = "jsmith-ad-credentials-vscode"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "jsmith_secret_version" {
  secret = google_secret_manager_secret.jsmith_secret.id
  secret_data = jsonencode({
    username = "VSCODE\\jsmith"
    password = local.passwords["jsmith"]
  })
}


# ==============================================================================
# USER: EMILY DAVIS
# ------------------------------------------------------------------------------
# Stores VSCODE\edavis credentials (friendly password above).
# ==============================================================================

resource "google_secret_manager_secret" "edavis_secret" {
  secret_id = "edavis-ad-credentials-vscode"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "edavis_secret_version" {
  secret = google_secret_manager_secret.edavis_secret.id
  secret_data = jsonencode({
    username = "VSCODE\\edavis"
    password = local.passwords["edavis"]
  })
}


# ==============================================================================
# USER: RAJ PATEL
# ------------------------------------------------------------------------------
# Stores VSCODE\rpatel credentials (friendly password above).
# ==============================================================================

resource "google_secret_manager_secret" "rpatel_secret" {
  secret_id = "rpatel-ad-credentials-vscode"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "rpatel_secret_version" {
  secret = google_secret_manager_secret.rpatel_secret.id
  secret_data = jsonencode({
    username = "VSCODE\\rpatel"
    password = local.passwords["rpatel"]
  })
}


# ==============================================================================
# USER: AMIT KUMAR
# ------------------------------------------------------------------------------
# Stores VSCODE\akumar credentials (friendly password above).
# ==============================================================================

resource "google_secret_manager_secret" "akumar_secret" {
  secret_id = "akumar-ad-credentials-vscode"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "akumar_secret_version" {
  secret = google_secret_manager_secret.akumar_secret.id
  secret_data = jsonencode({
    username = "VSCODE\\akumar"
    password = local.passwords["akumar"]
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