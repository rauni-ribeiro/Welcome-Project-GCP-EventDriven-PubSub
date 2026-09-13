# Rauni R Corp — Event-Driven Onboarding Architecture

```mermaid
flowchart TD
    P[Pub/Sub Topic: ecommerce<br/>AVRO schema + JSON encoding]

    P --> S1[Push Subscription<br/>cr-service-europe-west1-send-email-7q93yxva]
    S1 --> CR1[Cloud Run: send-email]
    CR1 --> SM[Secret Manager<br/>gmail-oath-token]
    CR1 --> GCS[Cloud Storage<br/>rauni-corp-deployment-files]
    CR1 --> Gmail[Gmail API]

    S1 -->|after repeated delivery failure| DLQ[Pub/Sub Topic<br/>welcome-email-dlq]
    DLQ --> DLS[Cloud Storage Subscription<br/>welcome-email-dlq-storage-sub]
    DLS --> GCS

    P --> ES[Eventarc-managed Pub/Sub subscription]
    ES --> EA[Eventarc Trigger<br/>rauni-corp-role-assignment-service-trigger]
    EA --> CR2[Cloud Run<br/>rauni-corp-role-assignment-service]
    CR2 --> MAP[ROLE_MAPPING<br/>business role -> GCP roles]
    MAP --> IAM[Cloud Resource Manager IAM API]
    IAM --> COND[IAM Condition<br/>modifiedGrantsByRole allowlist]

    SA1[SA: ecommerce-welcome-email] -. runtime identity .-> CR1
    SA2[SA: ecommerce-role-assignment-sa] -. runtime + trigger identity .-> CR2
```

## Security model

The role-assignment path intentionally has two layers:

1. **Application decision layer** — a Python `ROLE_MAPPING` converts business job roles into approved Google Cloud roles.
2. **Platform enforcement layer** — the runtime service account receives only a custom role containing `getIamPolicy` and `setIamPolicy`, with an IAM Condition that restricts modified grants to `roles/viewer` and `roles/logging.viewer`.

This means application logic is not treated as the final security boundary.
