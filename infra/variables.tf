variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "sauli-propertymgmt"
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "europe-north1"
}

variable "service_account_key_file" {
  description = "Path to the service account key file"
  type        = string
  default     = "../property-mgmt-app-key.json"
}
