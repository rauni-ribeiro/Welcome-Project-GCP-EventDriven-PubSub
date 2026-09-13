resource "google_project_iam_custom_role" "role_assignment" {
  project     = var.project_id
  role_id     = "CustomRole"
  title       = "ecommerce-role-assignment-role"
  description = "This is meant to be used on subscription 2 / project: ecommerce"
  stage       = "ALPHA"

  permissions = [
    "resourcemanager.projects.getIamPolicy",
    "resourcemanager.projects.setIamPolicy",
  ]
}

# Security layer 2:
# the application mapping chooses desired roles, while this IAM Condition
# constrains which grants the runtime identity is allowed to modify.
resource "google_project_iam_member" "role_assignment_custom_role" {
  project = var.project_id
  role    = google_project_iam_custom_role.role_assignment.name
  member  = "serviceAccount:${google_service_account.role_assignment.email}"

  condition {
    title       = "Limit_Role_Assignment"
    description = "Only approved onboarding roles can be modified"
    expression  = "api.getAttribute('iam.googleapis.com/modifiedGrantsByRole', []).hasOnly(['roles/viewer','roles/logging.viewer'])"
  }
}

# Current project-level permissions observed for the welcome-email runtime SA.
# Member resources are non-authoritative, so other members on the same roles are preserved.
resource "google_project_iam_member" "welcome_email_roles" {
  for_each = toset([
    "roles/pubsub.subscriber",
    "roles/run.invoker",
    "roles/secretmanager.secretAccessor",
    "roles/storage.objectViewer",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.welcome_email.email}"
}

# Required for authenticated Pub/Sub push OIDC token generation.
resource "google_project_iam_member" "pubsub_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${local.pubsub_service_agent}"
}

# Pub/Sub writes the DLQ archive into this bucket.
# These are resource-level permissions used by the Google-managed Pub/Sub service agent.
resource "google_storage_bucket_iam_member" "pubsub_dlq_object_creator" {
  bucket = google_storage_bucket.deployment.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${local.pubsub_service_agent}"
}

resource "google_storage_bucket_iam_member" "pubsub_dlq_bucket_reader" {
  bucket = google_storage_bucket.deployment.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${local.pubsub_service_agent}"
}

# Pub/Sub service agent can publish messages to the dead-letter topic.
resource "google_pubsub_topic_iam_member" "dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.welcome_email_dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${local.pubsub_service_agent}"
}

# Pub/Sub service agent can consume/finalize source messages after forwarding to the DLQ.
resource "google_pubsub_subscription_iam_member" "dlq_source_subscriber" {
  subscription = google_pubsub_subscription.welcome_email_push.id
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${local.pubsub_service_agent}"
}
