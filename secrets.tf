resource "google_secret_manager_secret" "gmail_oauth_token" {
  project   = var.project_id
  secret_id = var.gmail_secret_id

  replication {
    auto {}
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Intentionally no google_secret_manager_secret_version resource.
# The OAuth token payload must be injected out-of-band so it never enters
# Terraform configuration or Terraform state.
