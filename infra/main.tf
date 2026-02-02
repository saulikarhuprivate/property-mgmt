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

# --- Cloud Function Resources ---

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

# Zip the Cloud Function source
data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/cloud_functions/process_upload"
  output_path = "${path.module}/function.zip"
}

# Bucket for function artifacts
resource "google_storage_bucket" "artifacts" {
  name     = "${var.project_id}-artifacts"
  location = var.region
  uniform_bucket_level_access = true
}

# Upload source zip
resource "google_storage_bucket_object" "function_source" {
  name   = "source-${data.archive_file.function_zip.output_md5}.zip"
  bucket = google_storage_bucket.artifacts.name
  source = data.archive_file.function_zip.output_path
}

# Cloud Function (2nd Gen)
resource "google_cloudfunctions2_function" "process_upload" {
  name        = "process-upload"
  location    = var.region
  description = "Process energy consumption CSV uploads"

  build_config {
    runtime     = "python311"
    entry_point = "process_upload"
    source {
      storage_source {
        bucket = google_storage_bucket.artifacts.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
    service_account_email = google_service_account.function_identity.email
    environment_variables = {
      BIGQUERY_TABLE = "${var.project_id}.${google_bigquery_dataset.energy_data.dataset_id}.${google_bigquery_table.consumption.table_id}"
    }
  }
}

# Grant Storage Pub/Sub Publisher role to the Google Storage Service Agent
data "google_storage_project_service_account" "gcs_account" {
}

resource "google_project_iam_member" "gcs_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# Eventarc Trigger
resource "google_eventarc_trigger" "upload_trigger" {
  name     = "trigger-process-upload"
  location = var.region
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }
  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.upload_bucket.name
  }
  destination {
    cloud_run_service {
      service = "process-upload"
      region  = var.region
    }
  }
  service_account = google_service_account.function_identity.email
  
  depends_on = [
    google_project_iam_member.gcs_pubsub_publisher,
    google_project_iam_member.eventarc_receiver
  ]
}

# Grant Eventarc permission to invoke the function
resource "google_cloud_run_service_iam_member" "eventarc_invoker" {
  project  = var.project_id
  location = var.region
  service  = "process-upload"
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.function_identity.email}"
}

# Grant Eventarc Event Receiver role to the Function Identity
resource "google_project_iam_member" "eventarc_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.function_identity.email}"
}

# --- Cloud Build Configuration ---

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

# Cloud Build Trigger for property-mgmt
resource "google_cloudbuild_trigger" "property_mgmt" {
  name            = "property-mgmt"
  description     = "Build trigger for property management application"
  location        = var.region
  service_account = google_service_account.cloud_build.id

  github {
    owner = "saulikarhuprivate"
    name  = "property-mgmt"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"

  depends_on = [google_project_service.apis]
}
