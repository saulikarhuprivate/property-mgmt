provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file(var.service_account_key_file)
}

provider "google-beta" {
  project     = var.project_id
  region      = var.region
  credentials = file(var.service_account_key_file)
}

terraform {
  backend "gcs" {
    bucket      = "sauli-propertymgmt-terraform"
    prefix      = "terraform/state"
    credentials = "../property-mgmt-app-key.json"
  }
}
