# 🚀 Rauni R Corp — Terraform Reconstruction

This repository is a clean Terraform reconstruction of the **Rauni R Corp event-driven onboarding project** from the current Google Cloud environment.

<img width="1792" height="1008" alt="image" src="https://github.com/user-attachments/assets/571ed7be-704c-42ad-ba24-831aa4e6f425" />

It was intentionally rebuilt from the exported resource inventory instead of copying the raw `gcloud beta resource-config bulk-export` output. The project contains unrelated ACE study resources, and the raw export also included material that should not be committed.

The repository now includes both the **infrastructure-as-code layer** and the **application source code** used by the onboarding workflows.

---

## 🏗️ What is modeled

- 📬 Pub/Sub topic `ecommerce`
- 🧬 AVRO schema `ecommerce_order_schema`
- 📩 Welcome-email push subscription
- ☠️ Welcome-email DLQ topic
- 🗄️ DLQ -> Cloud Storage subscription (AVRO)
- ☁️ Cloud Run `send-email`
- ☁️ Cloud Run `rauni-corp-role-assignment-service`
- ⚡ Eventarc role-assignment trigger
- 🔄 Eventarc transport via the existing `ecommerce` topic
- 👤 Dedicated runtime service accounts
- 🔐 Custom project IAM role
- 🛡️ Conditional IAM binding using `modifiedGrantsByRole`
- 🔑 Secret Manager secret metadata only
- 🪣 Deployment / DLQ Cloud Storage bucket
- 🤖 Pub/Sub service-agent permissions needed by the DLQ path
- 🐍 Application source code for both onboarding services
- ✅ GitHub Actions CI for Terraform validation

---

## 🚫 What is intentionally NOT modeled

- Secret Manager **secret versions / secret payloads**
- OAuth refresh tokens
- Raw `token.json`
- Unrelated ACE labs (MIG, Cloud SQL, BigQuery labs, thumbnail app, older Eventarc lab, etc.)
- Cloud Run build/source-upload buckets and generated build metadata
- The Eventarc-generated Pub/Sub subscription as an independent resource

---

## ⚡ Why the Eventarc subscription is not a Terraform resource

For Pub/Sub-backed Eventarc triggers, Terraform declares the **transport topic**. Eventarc creates and manages its own transport subscription, and that subscription is an output-only property of the trigger.

So this is correct:

```text
ecommerce -> Eventarc-managed subscription -> Eventarc trigger -> Cloud Run
```

There should not be a second manually-managed Terraform subscription for the same Eventarc path.

---

## 🔐 Secret handling

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

---

## 🌱 Brownfield adoption: import first

These resources already exist.

**Do not run `terraform apply` before importing them.**

```bash
terraform init
chmod +x import-core.sh
./import-core.sh
terraform plan
```

The script imports the core infrastructure.

IAM member resources are not automatically imported because IAM import identifiers are more fragile, especially conditional bindings and `for_each` members. After the core import, inspect `terraform plan` and import the remaining IAM resources deliberately before applying.

The goal of the first plan is **reconciliation**, not blind recreation of an already-running environment.

---

## 🧠 Important current-state notes

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

---

## ✅ Continuous Integration

The repository includes a GitHub Actions workflow that automatically validates the Terraform configuration on pushes and pull requests targeting `main`.

Current CI checks include:

- 📥 Repository checkout
- 🧱 Terraform `1.16.2`
- 🔒 Provider dependency resolution using `.terraform.lock.hcl`
- 🧹 `terraform fmt -check -recursive`
- ⚙️ `terraform init -backend=false -input=false`
- ✅ `terraform validate -no-color`

The CI workflow intentionally uses:

```bash
terraform init -backend=false
```

This keeps validation independent from the current local Terraform state and prevents the CI runner from attempting to access or modify production infrastructure.

At this stage, the workflow is **CI-only** by design:

```text
Push / Pull Request
        ↓
GitHub Actions
        ↓
Terraform format check
        ↓
Terraform initialization
        ↓
Terraform validation
        ↓
✅ CI passed
```

No cloud credentials or static service-account keys are required for the current CI pipeline.

---

## 🔄 Expected future updates

The next evolution of the project is to extend the current CI workflow into a full **keyless CI/CD pipeline**.

Planned improvements include:

- 🔑 GitHub OIDC authentication with **Google Cloud Workload Identity Federation**
- 🚫 No long-lived service-account JSON keys stored in GitHub
- 🏗️ Automated application builds using **Cloud Build**
- 📦 Immutable container images stored in **Artifact Registry**
- 🚀 Automated deployment of both Cloud Run services
- 🌊 Progressive delivery / canary releases using **Cloud Deploy**
- 📊 Deployment health verification using Cloud Logging and Cloud Monitoring
- 🪣 Dedicated GCS bucket for Terraform remote state
- 🔍 Automated Terraform drift detection
- 🧪 Application-level tests in CI
- 🛡️ Additional IaC/security validation
- 🔁 Explicit retry with exponential backoff for concurrent IAM policy updates
- 📈 Log-based metrics and alerting for Cloud Run 5xx responses and DLQ activity

Target delivery architecture:

```text
GitHub
   ↓
GitHub Actions
   ↓
OIDC
   ↓
Workload Identity Federation
   ↓
Google Cloud
   ├── Terraform infrastructure workflow
   └── Application delivery workflow
          ↓
       Cloud Build
          ↓
     Artifact Registry
          ↓
      Cloud Deploy
          ↓
       Cloud Run
```

Terraform and the application deployment pipeline should have clearly separated ownership boundaries. Terraform manages the **platform, IAM, Pub/Sub, Eventarc, storage and service configuration**, while the deployment pipeline manages **application artifacts, revisions and rollout traffic**.

---

## 🛡️ Additional hardening opportunities

These are deliberately left as future improvements rather than silently changing the current environment:

- Move broad project-level permissions to resource-level permissions where possible.
- Add explicit handling for concurrent IAM policy updates (`etag` + retry / exponential backoff) in the role-assignment application.
- Add log-based metrics and alerting for Cloud Run 5xx and DLQ activity.
- Use a dedicated GCS bucket for Terraform remote state rather than the deployment-files bucket.
- Introduce controlled Terraform `plan` / `apply` workflows after remote state and Workload Identity Federation are configured.
- Protect `main` with pull-request checks before infrastructure or application deployment.

---

## 📁 Repository structure

```text
.
├── .github/
│   └── workflows/
│       └── ci.yml
├── services/
│   ├── send-email/
│   └── role-assignment/
├── ARCHITECTURE.md
├── README.md
├── cloudrun.tf
├── eventarc.tf
├── iam.tf
├── import-core.sh
├── outputs.tf
├── provider.tf
├── pubsub.tf
├── secrets.tf
├── service-accounts.tf
├── storage.tf
├── terraform.tfvars.example
├── variables.tf
└── versions.tf
```

### Key files

- `provider.tf` / `versions.tf` — Terraform/provider configuration
- `service-accounts.tf` — dedicated runtime identities
- `pubsub.tf` — topic, schema, push subscription, DLQ and storage subscription
- `cloudrun.tf` — both Cloud Run services
- `eventarc.tf` — Eventarc trigger and transport
- `iam.tf` — custom role, IAM Condition and current project-level runtime permissions
- `storage.tf` — artifact/DLQ bucket and Pub/Sub bucket permissions
- `secrets.tf` — secret metadata only
- `outputs.tf` — useful resource identifiers
- `services/` — source code for the two Cloud Run onboarding workloads
- `.github/workflows/ci.yml` — automated Terraform CI validation
- `ARCHITECTURE.md` — Mermaid architecture diagram
- `import-core.sh` — brownfield import helper

---

## 🧰 Recommended local workflow

```bash
terraform fmt -recursive
terraform init
./import-core.sh
terraform validate
terraform plan
```

Treat the first plan as a **reconciliation exercise**, not as permission to apply blindly. The source environment was originally built manually and through managed Google Cloud integrations, so some system-generated metadata will not belong in clean IaC.

---

## 🎯 Current project status

The current implementation demonstrates:

- ☁️ Google Cloud serverless architecture
- ⚡ Event-driven design with Pub/Sub and Eventarc
- 🔐 IAM automation with custom roles and conditional access
- 🧱 Brownfield Terraform adoption
- 📨 Automated onboarding workflows
- ☠️ Dead-letter handling and persistence
- 🔑 Secure secret separation
- 🐍 Version-controlled application workloads
- ✅ Automated Terraform CI with GitHub Actions

The project is considered **feature-complete for the current portfolio scope**, with full CD, progressive delivery, remote state and observability automation documented as the next engineering phase.
