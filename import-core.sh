#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-project-ace-cert-rauni}"
REGION="${REGION:-europe-west1}"

echo "Importing existing Rauni R Corp resources into Terraform state..."
echo "Run 'terraform.exe init' before this script."

terraform.exe import google_pubsub_schema.ecommerce \
  "projects/${PROJECT_ID}/schemas/ecommerce_order_schema"

terraform.exe import google_pubsub_topic.ecommerce \
  "projects/${PROJECT_ID}/topics/ecommerce"

terraform.exe import google_pubsub_topic.welcome_email_dlq \
  "projects/${PROJECT_ID}/topics/welcome-email-dlq"

terraform.exe import google_pubsub_subscription.welcome_email_push \
  "projects/${PROJECT_ID}/subscriptions/cr-service-europe-west1-send-email-7q93yxva"

terraform.exe import google_pubsub_subscription.welcome_email_dlq_storage \
  "projects/${PROJECT_ID}/subscriptions/welcome-email-dlq-storage-sub"

terraform.exe import google_storage_bucket.deployment \
  "rauni-corp-deployment-files"

terraform.exe import google_secret_manager_secret.gmail_oauth_token \
  "projects/${PROJECT_ID}/secrets/gmail-oath-token"

terraform.exe import google_service_account.welcome_email \
  "projects/${PROJECT_ID}/serviceAccounts/ecommerce-welcome-email@${PROJECT_ID}.iam.gserviceaccount.com"

terraform.exe import google_service_account.role_assignment \
  "projects/${PROJECT_ID}/serviceAccounts/ecommerce-role-assignment-sa@${PROJECT_ID}.iam.gserviceaccount.com"

terraform.exe import google_project_iam_custom_role.role_assignment \
  "projects/${PROJECT_ID}/roles/CustomRole"

terraform.exe import google_cloud_run_v2_service.send_email \
  "projects/${PROJECT_ID}/locations/${REGION}/services/send-email"

terraform.exe import google_cloud_run_v2_service.role_assignment \
  "projects/${PROJECT_ID}/locations/${REGION}/services/rauni-corp-role-assignment-service"

terraform.exe import google_eventarc_trigger.role_assignment \
  "projects/${PROJECT_ID}/locations/${REGION}/triggers/rauni-corp-role-assignment-service-trigger"



echo
echo "Core resource import complete."
echo "IAM member imports are intentionally not automated here; see README.md."
echo "Next: terraform.exe plan"
