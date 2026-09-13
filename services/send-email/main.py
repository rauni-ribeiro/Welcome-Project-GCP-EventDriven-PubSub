import base64
import json
import functions_framework

from email.message import EmailMessage

from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from google.cloud import secretmanager
from google.oauth2.credentials import Credentials
from google.cloud import storage


@functions_framework.http
def hello_pubsub(request):
    envelope = request.get_json(silent=True)

    if not envelope:
        return 'Bad Request: missing JSON payload', 400

    pubsub_message = envelope.get('message')

    if not pubsub_message or 'data' not in pubsub_message:
        return 'Bad Request: invalid Pub/Sub format', 400

    try:
        data_base64 = pubsub_message['data']
        data_string = base64.b64decode(data_base64).decode('utf-8')
        payload = json.loads(data_string)

        print(f"Event received successfully! Data: {payload}")

        target_email = payload.get("email")
        customer_name = payload.get("first_name")

        if target_email and customer_name:
            print(
                f"Sending logic: Welcome {customer_name}, "
                f"email to {target_email}"
            )
        else:
            raise ValueError("Message received without email or first_name.")

        # Load OAuth secret from Secret Manager
        secret_payload = load_gmail_secret()

        gmail_send_message(
            secret_payload,
            target_email,
            customer_name
        )

        return 'OK', 200

    except Exception as e:
        print(f"Processing error: {e}")
        return f"Internal error: {e}", 500


###########################################

# defining Secret Manager's client:

def load_gmail_secret():

    project_id = "222270384943"
    secret_id = "gmail-oath-token"
    version_id = "latest"

    client = secretmanager.SecretManagerServiceClient()

    # Build the resource name of the secret version.
    name = (
        f"projects/{project_id}/secrets/"
        f"{secret_id}/versions/{version_id}"
    )

    # Access the secret version
    response = client.access_secret_version(
        request={"name": name}
    )

    secret_payload = response.payload.data.decode("UTF-8")

    if secret_payload:
        print("Secret successfully loaded")

    return secret_payload


def gmail_send_message(
    secret_payload,
    target_email,
    customer_name
):

    sender = "raunirr98@gmail.com"
    receiver = target_email

    credentials_info = json.loads(secret_payload)

    creds = Credentials.from_authorized_user_info(
        credentials_info,
        scopes=credentials_info.get("scopes")
    )

    try:
        # Create Gmail client
        service = build(
            "gmail",
            "v1",
            credentials=creds
        )

        message = EmailMessage()

        message.set_content(
            f"Hello {customer_name},\n\n"
            "Welcome to Rauni R Corp. 👋\n\n"
            "We’re very happy to have you with us and excited to welcome "
            "you to the team.\n\n"
            "To help you get started, we’ve prepared a few onboarding "
            "resources with the first steps you’ll need to complete.\n\n"
            "Please review the attached onboarding guide and feel free "
            "to reach out if you have any questions along the way.\n\n"
            "We’re looking forward to working with you and wish you "
            "a great start!\n\n"
            "Best regards,\n\n"
            "Rauni R Corp.\n"
            "Cloud & Automation Team"
        )

        message["To"] = receiver
        message["From"] = sender
        message["Subject"] = (
            "Welcome email - Onboarding next steps! Rauni R Corp."
        )

        ###########################################


        storage_client = storage.Client()
        bucket = storage_client.bucket("rauni-corp-deployment-files")
        blob = bucket.blob("Rauni_R_Corp_Onboarding_Guide.pdf")
        pdf_bytes = blob.download_as_bytes()

        print("Onboarding PDF successfully downloaded from Cloud Storage")

        ###########################################


        message.add_attachment(
            pdf_bytes,
            maintype="application",
            subtype="pdf",
            filename="Rauni_R_Corp_Onboarding_Guide.pdf"
        )

        print("Onboarding PDF successfully attached")


        ###########################################
        

        # Encode message into a URL-safe Base64 string
        encoded_message = base64.urlsafe_b64encode(
            message.as_bytes()
        ).decode()

        # Gmail API expects the encoded MIME message in "raw"
        send_message = {
            "raw": encoded_message
        }

        send_message = (
            service.users()
            .messages()
            .send(
                userId="me",
                body=send_message
            )
            .execute()
        )

        print(f'Message Id: {send_message["id"]}')

    except HttpError as error:
        print(f"An error occurred: {error}")
        raise

    return send_message