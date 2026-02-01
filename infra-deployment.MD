# GCP Deployment Instructions

This guide documents the steps to deploy the Property Management System to a fresh Google Cloud Platform (GCP) project.

## Prerequisites
1.  Google Cloud SDK installed and authenticated.
2.  Terraform installed.
    *   **Windows**: Run `winget install HashiCorp.Terraform` in PowerShell, then restart your terminal.
    *   **Mac/Linux**: Follow official HashiCorp instructions.
3.  Python 3.11+ installed.

## 1. Login and Set Project
Authenticate with Google Cloud and set the active project.
Replace `[PROJECT_ID]` with your actual GCP project ID (e.g., `sauli-propertymgmt`).

```powershell
# Login to Google Cloud
gcloud auth login

# Set the active project
$PROJECT_ID="[PROJECT_ID]"
gcloud config set project $PROJECT_ID
```

## 2. Enable Prerequisite APIs
Enable the core APIs required for Terraform to manage the rest of the infrastructure.
```powershell
gcloud services enable serviceusage.googleapis.com cloudresourcemanager.googleapis.com iam.googleapis.com
```

## 3. Create Service Account & Grant Roles
Create the `terraform-deployer` service account and grant it the necessary permissions.

```powershell
$SA_NAME="terraform-deployer"
gcloud iam service-accounts create $SA_NAME --display-name "Terraform Deployment Account"

$SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# Roles for Cloud Functions, BigQuery, Storage, Eventarc, Run, etc.
$ROLES = @(
    "roles/serviceusage.serviceUsageAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/storage.admin",
    "roles/bigquery.admin",
    "roles/cloudfunctions.admin",
    "roles/run.admin",
    "roles/eventarc.admin",
    "roles/pubsub.editor",
    "roles/artifactregistry.admin",
    "roles/datastore.owner"
)

foreach ($role in $ROLES) {
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_EMAIL" --role=$role
}
```

## 4. Generate & Download Key
Create the service account key and save it as `property-mgmt-app-key.json` in the root of the project.
```powershell
gcloud iam service-accounts keys create property-mgmt-app-key.json --iam-account=$SA_EMAIL
```

## 5. Create Terraform State Bucket
Create the GCS bucket for storing Terraform state (Terraform cannot create its own backend).
Replace `[TERRAFORM_STATE_BUCKET]` with a globally unique bucket name (e.g., `sauli-propertymgmt-terraform`).

```powershell
$TERRAFORM_BUCKET="[TERRAFORM_STATE_BUCKET]"
gcloud storage buckets create gs://$TERRAFORM_BUCKET --location=europe-north1
```

## 6. Update Configuration Files
Before deploying, ensure your configuration files match your new project settings.

1.  **`infra/variables.tf`**: Update the `project_id` default value.
2.  **`infra/provider.tf`**: Update the `backend "gcs"` block with your new `$TERRAFORM_BUCKET` name.

## 7. Deploy Infrastructure
Navigate to the `infra` directory, initialize Terraform, and apply the configuration.

```powershell
cd infra
terraform init
terraform apply
```
