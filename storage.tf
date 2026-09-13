resource "google_storage_bucket" "deployment" {
  project  = var.project_id
  name     = var.deployment_bucket_name
  location = var.region

  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

