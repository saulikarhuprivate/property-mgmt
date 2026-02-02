# Enable necessary APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "firestore.googleapis.com",
    "bigquery.googleapis.com",
    "cloudfunctions.googleapis.com",
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com"
  ])

  service            = each.key
  disable_on_destroy = false
}

# Cloud Storage Bucket for CSV Uploads
resource "google_storage_bucket" "upload_bucket" {
  name     = "${var.project_id}-uploads"
  location = var.region
  uniform_bucket_level_access = true
  cors {
    origin          = ["*"]
    method          = ["GET", "POST", "PUT", "HEAD", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

# BigQuery Dataset
resource "google_bigquery_dataset" "energy_data" {
  dataset_id                  = "energy_data"
  friendly_name               = "Energy Consumption Data"
  description                 = "Dataset for storing energy consumption records"
  location                    = var.region
  default_table_expiration_ms = null
}

# BigQuery Table
resource "google_bigquery_table" "consumption" {
  dataset_id = google_bigquery_dataset.energy_data.dataset_id
  table_id   = "consumption"

  schema = <<EOF
[
  {
    "name": "customer_id",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "The ID of the customer who owns this record"
  },
  {
    "name": "property_id",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "The ID of the property associated with this record"
  },
  {
    "name": "timestamp",
    "type": "TIMESTAMP",
    "mode": "REQUIRED",
    "description": "The timestamp of the consumption reading"
  },
  {
    "name": "consumption_kwh",
    "type": "FLOAT",
    "mode": "REQUIRED",
    "description": "Energy consumption in kWh"
  },
  {
    "name": "provider",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "The utility provider name"
  }
]
EOF
}

# Firestore Database (Native Mode)
resource "google_firestore_database" "database" {
  name                              = "(default)"
  location_id                       = var.region
  type                              = "FIRESTORE_NATIVE"
  concurrency_mode                  = "OPTIMISTIC"
  app_engine_integration_mode       = "DISABLED"
  
  depends_on = [google_project_service.apis]
}



# --- Cloud Build Configuration ---

# Service Account for Cloud Function
resource "google_service_account" "function_identity" {
  account_id   = "function-identity"
  display_name = "Cloud Function Identity"
}

# Grant Function Identity access to Read from Upload Bucket
resource "google_storage_bucket_iam_member" "read_upload" {
  bucket = google_storage_bucket.upload_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.function_identity.email}"
}

# Grant Function Identity access to Write to BigQuery
resource "google_bigquery_dataset_iam_member" "write_bq" {
  dataset_id = google_bigquery_dataset.energy_data.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.function_identity.email}"
}

# Grant Function Identity access to create BigQuery Jobs
resource "google_project_iam_member" "bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.function_identity.email}"
}

# Service Account for Cloud Build
resource "google_service_account" "cloud_build" {
  account_id   = "cloud-build-sa"
  display_name = "Cloud Build Service Account"
}

# Grant Cloud Build access to deploy Cloud Run services
resource "google_project_iam_member" "cloud_build_runner" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Grant Cloud Build access to push images to Artifact Registry
resource "google_project_iam_member" "cloud_build_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Grant Cloud Build access to use service accounts
resource "google_project_iam_member" "cloud_build_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Grant Cloud Build access to deploy Cloud Functions
resource "google_project_iam_member" "cloud_build_function_developer" {
  project = var.project_id
  role    = "roles/cloudfunctions.developer"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Grant Cloud Build access to use Cloud Build Service Agent
resource "google_project_iam_member" "cloud_build_logs_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Cloud Build Trigger for property-mgmt
resource "google_cloudbuild_trigger" "property_mgmt" {
  name            = "property-mgmt"
  description     = "Build trigger for property management application"
  location        = var.region
  service_account = google_service_account.cloud_build.id

  repository_event_config {
    repository = "projects/sauli-propertymgmt/locations/europe-north1/connections/sauli-github/repositories/saulikarhuprivate-property-mgmt"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"

  depends_on = [google_project_service.apis]
}

# Cloud Build Trigger for process_upload function
resource "google_cloudbuild_trigger" "process_upload" {
  name            = "process-upload-function"
  description     = "Build trigger for process_upload cloud function"
  location        = var.region
  service_account = google_service_account.cloud_build.id

  repository_event_config {
    repository = "projects/sauli-propertymgmt/locations/europe-north1/connections/sauli-github/repositories/saulikarhuprivate-property-mgmt"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild-function.yaml"

  depends_on = [google_project_service.apis]
}
