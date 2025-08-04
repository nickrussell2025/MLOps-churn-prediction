variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west2"
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
