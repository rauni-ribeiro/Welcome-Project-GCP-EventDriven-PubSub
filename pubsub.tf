resource "google_pubsub_schema" "ecommerce" {
  project    = var.project_id
  name       = "ecommerce_order_schema"
  type       = "AVRO"
  definition = <<-EOT
{
  "type": "record",
  "name": "EcommerceRauniOrders",
  "fields": [
    {"name": "coolproductornot_id", "type": "boolean"},
    {"name": "order_id", "type": "string"},
    {"name": "customer_id", "type": "string"},
    {"name": "product_id", "type": "string"},
    {"name": "quantity", "type": "int"},
    {"name": "total_price", "type": "double"},
    {"name": "timestamp", "type": "string"},
    {"name": "age", "type": ["null", "int"], "default": null},
    {"name": "email", "type": ["null", "string"], "default": null},
    {"name": "first_name", "type": ["null", "string"], "default": null},
    {"name": "last_name", "type": ["null", "string"], "default": null},
    {"name": "job_role", "type": ["null", "string"], "default": null}
  ]
}
  EOT
}

resource "google_pubsub_topic" "ecommerce" {
  project = var.project_id
  name    = "ecommerce"

  schema_settings {
    schema   = google_pubsub_schema.ecommerce.id
    encoding = "JSON"
  }
}

resource "google_pubsub_topic" "welcome_email_dlq" {
  project = var.project_id
  name    = "welcome-email-dlq"
}

# Direct Pub/Sub push path -> Cloud Run welcome-email service.
resource "google_pubsub_subscription" "welcome_email_push" {
  project = var.project_id
  name    = "cr-service-europe-west1-send-email-7q93yxva"
  topic   = google_pubsub_topic.ecommerce.id

  ack_deadline_seconds       = 10
  message_retention_duration = "604800s"

  expiration_policy {
    ttl = "2678400s"
  }

  push_config {
    push_endpoint = google_cloud_run_v2_service.send_email.uri

    attributes = {
      "x-goog-version" = "v1"
    }

    oidc_token {
      service_account_email = google_service_account.welcome_email.email
    }
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.welcome_email_dlq.id
    max_delivery_attempts = 5
  }

  depends_on = [
    google_project_iam_member.pubsub_token_creator,
    google_project_iam_member.welcome_email_roles,
    google_pubsub_topic_iam_member.dlq_publisher
  ]
}

# Persists dead-letter messages as AVRO in Cloud Storage.
resource "google_pubsub_subscription" "welcome_email_dlq_storage" {
  project = var.project_id
  name    = "welcome-email-dlq-storage-sub"
  topic   = google_pubsub_topic.welcome_email_dlq.id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"

  expiration_policy {
    ttl = "2678400s"
  }

  cloud_storage_config {
    bucket          = google_storage_bucket.deployment.name
    filename_prefix = "dlq/welcome-email/"
    filename_suffix = ".avro"
    max_duration    = "60s"

    avro_config {
      write_metadata = true
    }
  }

  depends_on = [
    google_storage_bucket_iam_member.pubsub_dlq_object_creator,
    google_storage_bucket_iam_member.pubsub_dlq_bucket_reader,
  ]
}


