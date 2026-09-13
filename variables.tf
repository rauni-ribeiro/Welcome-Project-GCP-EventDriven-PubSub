variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
  default     = "project-ace-cert-rauni"
}

variable "region" {
  description = "Primary region for the Rauni R Corp services."
  type        = string
  default     = "europe-west1"
}

variable "deployment_bucket_name" {
  description = "Bucket used for onboarding artifacts and DLQ output."
  type        = string
  default     = "rauni-corp-deployment-files"
}

variable "gmail_secret_id" {
  description = "Secret Manager secret ID containing the Gmail OAuth authorized-user token."
  type        = string
  default     = "gmail-oath-token"
}

variable "send_email_image" {
  description = "Current Cloud Run image for the welcome-email service. Replace when deploying a new revision."
  type        = string
  default     = "europe-west1-docker.pkg.dev/project-ace-cert-rauni/cloud-run-source-deploy/send-email@sha256:da5630555aeb741c1edfc45100d605dd7503cd86ab854a26c7042a15ad062da3"
}

variable "role_assignment_image" {
  description = "Current Cloud Run image for the role-assignment service. Replace when deploying a new revision."
  type        = string
  default     = "europe-west1-docker.pkg.dev/project-ace-cert-rauni/cloud-run-source-deploy/rauni-corp-role-assignment-service@sha256:a8d66c9bb49e75a90c790d3da61659ce0222de453c1391d25858ea7c44319520"
}
