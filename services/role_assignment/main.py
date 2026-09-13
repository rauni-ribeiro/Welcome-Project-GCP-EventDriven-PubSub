import base64
import json
import functions_framework
import google.auth

from googleapiclient.discovery import build
from googleapiclient.errors import HttpError


PROJECT_ID = "project-ace-cert-rauni"


ROLE_MAPPING = {
    "cloud_engineer": [
        "roles/viewer",
        "roles/logging.viewer"
    ],
    "support_engineer": [
        "roles/viewer"
    ],
    "frontend_engineer": [
        "roles/viewer"
    ],
    "devops_engineer": [
        "roles/viewer",
        "roles/logging.viewer"
    ]
}


@functions_framework.cloud_event
def hello_pubsub(cloud_event):

    # Decode Pub/Sub message
    data_base64 = cloud_event.data["message"]["data"]
    data_string = base64.b64decode(data_base64).decode("utf-8")
    payload = json.loads(data_string)

    print(f"Event received: {payload}")

    # Get employee information from payload
    job_role = payload.get("job_role")
    target_email = payload.get("email")

    if not job_role or not target_email:
        raise ValueError("Message must contain email and job_role.")

    # Translate business role -> approved GCP roles
    roles_to_assign = ROLE_MAPPING.get(job_role)

    if not roles_to_assign:
        raise ValueError(
            f"Unsupported job role: {job_role}"
        )

    print(
        f"Provisioning {target_email} "
        f"as {job_role}: {roles_to_assign}"
    )

    assign_roles(
        target_email,
        roles_to_assign
    )

    print("Role assignment completed successfully.")


###########################################


def assign_roles(target_email, roles_to_assign):

    # Uses the Cloud Run runtime Service Account
    credentials, _ = google.auth.default()

    service = build(
        "cloudresourcemanager",
        "v1",
        credentials=credentials
    )

    try:

        # Read current IAM Policy
        policy = (
            service.projects()
            .getIamPolicy(
                resource=PROJECT_ID,
                body={}
            )
            .execute()
        )

        bindings = policy.get("bindings", [])

        principal = f"user:{target_email}"

        for role in roles_to_assign:

            role_found = False

            for binding in bindings:

                # Only modify normal bindings for this role
                if (
                    binding.get("role") == role
                    and "condition" not in binding
                ):

                    members = binding.setdefault(
                        "members",
                        []
                    )

                    if principal not in members:
                        members.append(principal)

                    role_found = True
                    break

            # If the role has no binding yet, create one
            if not role_found:

                bindings.append({
                    "role": role,
                    "members": [
                        principal
                    ]
                })

        policy["bindings"] = bindings

        # Write updated IAM Policy
        (
            service.projects()
            .setIamPolicy(
                resource=PROJECT_ID,
                body={
                    "policy": policy
                }
            )
            .execute()
        )

        print(
            f"{principal} successfully added "
            f"to roles: {roles_to_assign}"
        )

    except HttpError as error:
        print(
            f"IAM assignment error: {error}"
        )
        raise