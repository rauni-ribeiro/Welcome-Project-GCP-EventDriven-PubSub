output "ecommerce_topic" {
  value = google_pubsub_topic.ecommerce.id
}

output "send_email_service_uri" {
  value = google_cloud_run_v2_service.send_email.uri
}

output "role_assignment_service_uri" {
  value = google_cloud_run_v2_service.role_assignment.uri
}

output "eventarc_trigger" {
  value = google_eventarc_trigger.role_assignment.id
}

output "deployment_bucket" {
  value = google_storage_bucket.deployment.url
}

output "welcome_email_service_account" {
  value = google_service_account.welcome_email.email
}

output "role_assignment_service_account" {
  value = google_service_account.role_assignment.email
}
