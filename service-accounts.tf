resource "google_service_account" "welcome_email" {
  project      = var.project_id
  account_id   = "ecommerce-welcome-email"
  display_name = "ecommerce-welcome-email"
  description  = "gives a welcome message to the publisher (new hire)"
}

resource "google_service_account" "role_assignment" {
  project      = var.project_id
  account_id   = "ecommerce-role-assignment-sa"
  display_name = "ecommerce-role-assignment-sa"
  description  = "This SA is meant to assign roles to new principals (new hires)"
}
