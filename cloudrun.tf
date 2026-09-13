resource "google_cloud_run_v2_service" "send_email" {
  project             = var.project_id
  name                = "send-email"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = true

  template {
    service_account                  = google_service_account.welcome_email.email
    timeout                          = "300s"
    max_instance_request_concurrency = 80

    scaling {
      max_instance_count = 20
    }

    containers {
      image = var.send_email_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        failure_threshold = 1
        period_seconds    = 240
        timeout_seconds   = 240

        tcp_socket {
          port = 8080
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      build_config,
    ]
  }
}


resource "google_cloud_run_v2_service" "role_assignment" {
  project             = var.project_id
  name                = "rauni-corp-role-assignment-service"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = true

  template {
    service_account                  = google_service_account.role_assignment.email
    timeout                          = "300s"
    max_instance_request_concurrency = 80

    scaling {
      max_instance_count = 20
    }

    containers {
      image = var.role_assignment_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        failure_threshold = 1
        period_seconds    = 240
        timeout_seconds   = 240

        tcp_socket {
          port = 8080
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      build_config,
    ]
  }

  
}


# Eventarc invokes the protected role-assignment service with this identity.
resource "google_cloud_run_v2_service_iam_member" "role_assignment_invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_service.role_assignment.location
  name     = google_cloud_run_v2_service.role_assignment.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.role_assignment.email}"
}