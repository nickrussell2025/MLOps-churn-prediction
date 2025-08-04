# infrastructure/outputs.tf - Output declarations for infrastructure layer

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "cloud_sql_ip" {
  description = "Cloud SQL instance IP address"
  value       = google_sql_database_instance.mlflow_db.ip_address[0].ip_address
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.mlflow.name
}

output "database_user" {
  description = "Database user"
  value       = google_sql_user.mlflow_user.name
}

output "monitoring_database_name" {
  description = "Monitoring database name"
  value       = google_sql_database.monitoring.name
}

output "service_account_email" {
  description = "Service account email for Cloud Run"
  value       = google_service_account.cloud_run_sa.email
}

output "artifacts_bucket_url" {
  description = "GCS artifacts bucket URL"
  value       = "gs://${google_storage_bucket.mlflow_artifacts.name}"
}

output "artifacts_bucket_name" {
  description = "GCS artifacts bucket name"
  value       = google_storage_bucket.mlflow_artifacts.name
}

output "cloud_sql_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.mlflow_db.name
}

output "grafana_database_name" {
    description = "Grafana database name"
    value       = google_sql_database.grafana.name
}
