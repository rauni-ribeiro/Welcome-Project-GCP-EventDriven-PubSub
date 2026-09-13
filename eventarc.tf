resource "google_eventarc_trigger" "role_assignment" {
  project         = var.project_id
  name            = "rauni-corp-role-assignment-service-trigger"
  location        = var.region
  service_account = google_service_account.role_assignment.email

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.role_assignment.name
      region  = var.region
      path    = "/"
    }
  }

  transport {
    pubsub {
      topic = google_pubsub_topic.ecommerce.id
    }
  }

  depends_on = [
    google_cloud_run_v2_service_iam_member.role_assignment_invoker
  ]
}

# IMPORTANT:
# The Pub/Sub subscription used by Eventarc is intentionally NOT declared as a
# google_pubsub_subscription resource. Eventarc creates/manages that subscription
# and exposes it as an output-only transport resource.
