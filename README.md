# Rauni R Corp — Terraform Reconstruction

This directory is a clean Terraform reconstruction of the **Rauni R Corp event-driven onboarding project** from the current Google Cloud environment.

It was intentionally rebuilt from the exported resource inventory instead of copying the raw `gcloud beta resource-config bulk-export` output. The project contains unrelated ACE study resources, and the raw export also included material that should not be committed.

## What is modeled

- Pub/Sub topic `ecommerce`
- AVRO schema `ecommerce_order_schema`
- Welcome-email push subscription
- Welcome-email DLQ topic
- DLQ -> Cloud Storage subscription (AVRO)
- Cloud Run `send-email`
- Cloud Run `rauni-corp-role-assignment-service`
- Eventarc role-assignment trigger
- Eventarc transport via the existing `ecommerce` topic
- Dedicated runtime service accounts
- Custom project IAM role
- Conditional IAM binding using `modifiedGrantsByRole`
- Secret Manager secret metadata only
- Deployment / DLQ Cloud Storage bucket
- Pub/Sub service-agent permissions needed by the DLQ path

## What is intentionally NOT modeled

- Secret Manager **secret versions / secret payloads**
- OAuth refresh tokens
- Raw `token.json`
- Unrelated ACE labs (MIG, Cloud SQL, BigQuery labs, thumbnail app, older Eventarc lab, etc.)
- Cloud Run build/source-upload buckets and generated build metadata
- The Eventarc-generated Pub/Sub subscription as an independent resource

### Why the Eventarc subscription is not a Terraform resource

For Pub/Sub-backed Eventarc triggers, Terraform declares the **transport topic**. Eventarc creates and manages its own transport subscription, and that subscription is an output-only property of the trigger.

So this is correct:

`ecommerce -> Eventarc-managed subscription -> Eventarc trigger -> Cloud Run`

and there should not be a second manually-managed Terraform subscription for the same Eventarc path.

## Secret handling

`secrets.tf` creates/manages only the `gmail-oath-token` secret container.

The secret payload is deliberately injected outside Terraform. This avoids writing the OAuth token into:

- Git
- `.tf` files
- plan files
- Terraform state

Example manual secret-version update:

```bash
gcloud secrets versions add gmail-oath-token \
  --data-file=token.json \
  --project=project-ace-cert-rauni
```

## Brownfield adoption: import first

These resources already exist.

**Do not run `terraform apply` before importing them.**

```bash
terraform init
chmod +x import-core.sh
./import-core.sh
terraform plan
```

The script imports the core infrastructure.

IAM member resources are not automatically imported because IAM import identifiers are more fragile (especially conditional bindings and `for_each` members). After the core import, inspect `terraform plan` and import the remaining IAM resources deliberately before applying.

## Important current-state notes

- The welcome-email runtime identity currently has project-level `roles/run.invoker`, `roles/pubsub.subscriber`, `roles/secretmanager.secretAccessor`, and `roles/storage.objectViewer`.
- The role-assignment service account uses the custom role `projects/project-ace-cert-rauni/roles/CustomRole`.
- That custom role contains only:
  - `resourcemanager.projects.getIamPolicy`
  - `resourcemanager.projects.setIamPolicy`
- Its conditional binding allows modifications only to:
  - `roles/viewer`
  - `roles/logging.viewer`
- The welcome-email source subscription uses `max_delivery_attempts = 5`.
- DLQ messages are persisted as AVRO under `dlq/welcome-email/`.

## Hardening opportunities

These are deliberately left as future improvements rather than silently changing the current environment:

- Move broad project-level permissions to resource-level permissions where possible.
- Add explicit handling for concurrent IAM policy updates (`etag` + retry / exponential backoff) in the role-assignment application.
- Add log-based metrics and alerting for Cloud Run 5xx and DLQ activity.
- Use a dedicated GCS bucket for Terraform remote state rather than the deployment-files bucket.
- Add CI/CD for the two Cloud Run application images.

## Files

- `provider.tf` / `versions.tf` — Terraform/provider configuration
- `service-accounts.tf` — dedicated runtime identities
- `pubsub.tf` — topic, schema, push subscription, DLQ and storage subscription
- `cloudrun.tf` — both Cloud Run services
- `eventarc.tf` — Eventarc trigger and transport
- `iam.tf` — custom role, IAM Condition and current project-level runtime permissions
- `storage.tf` — artifact/DLQ bucket and Pub/Sub bucket permissions
- `secrets.tf` — secret metadata only
- `outputs.tf` — useful resource identifiers
- `ARCHITECTURE.md` — Mermaid architecture diagram
- `import-core.sh` — brownfield import helper

## Recommended workflow

```bash
terraform fmt -recursive
terraform init
./import-core.sh
terraform validate
terraform plan
```

Treat the first plan as a **reconciliation exercise**, not as permission to apply blindly. The source environment was originally built manually and through managed Google Cloud integrations, so some system-generated metadata will not belong in clean IaC.
