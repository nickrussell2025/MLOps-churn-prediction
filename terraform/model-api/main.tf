# model-api/main.tf - Model API service with temporary test container

locals {
    infra  = data.terraform_remote_state.infrastructure.outputs
    mlflow = data.terraform_remote_state.mlflow.outputs
}

resource "google_cloud_run_service" "model_api" {
    name     = "model-api"
    location = local.infra.region

    template {
        metadata {
            annotations = {
                "autoscaling.knative.dev/maxScale"         = "50"
                "run.googleapis.com/execution-environment" = "gen2"
                "run.googleapis.com/cloudsql-instances"    = "${local.infra.project_id}:${local.infra.region}:${local.infra.cloud_sql_instance_name}"
            }
        }
        spec {
            service_account_name = local.infra.service_account_email
            containers {
                image = "europe-west2-docker.pkg.dev/mlops-churn-prediction-465023/mlops-repo/model-api:latest"
                resources {
                    limits = {
                        memory = "1Gi"
                        cpu    = "1000m"
                    }
                }
                env {
                    name  = "MLFLOW_TRACKING_URI"
                    value = "https://mlflow-working-139798376302.europe-west2.run.app"
                }
                env {
                    name  = "DATABASE_HOST"
                    value = "/cloudsql/${local.infra.project_id}:${local.infra.region}:${local.infra.cloud_sql_instance_name}"
                }
                env {
                    name  = "DATABASE_NAME"
                    value = local.infra.monitoring_database_name
                }
                env {
                    name  = "DATABASE_USER"
                    value = local.infra.database_user
                }
                env {
                    name  = "DATABASE_PASSWORD"
                    value = var.db_password
                }
                env {
                    name  = "DEPLOYMENT_MODE"
                    value = "cloud"
                }
                env {
                    name  = "USE_CLOUD_STORAGE"
                    value = "true"
                }
                env {
                    name  = "BUCKET_NAME"
                    value = local.infra.artifacts_bucket_name
                }
                ports {
                    container_port = 8080
                }
                startup_probe {
                    http_get {
                        path = "/"
                        port = 8080
                    }
                    initial_delay_seconds = 30
                    period_seconds        = 10
                    timeout_seconds       = 5
                    failure_threshold     = 12
                }
            }
            timeout_seconds = 300
        }
    }
    traffic {
        percent         = 100
        latest_revision = true
    }
}

resource "google_cloud_run_service_iam_member" "model_api_public" {
    service  = google_cloud_run_service.model_api.name
    location = google_cloud_run_service.model_api.location
    role     = "roles/run.invoker"
    member   = "allUsers"
}

output "model_api_url" {
    description = "Model API service URL"
    value       = google_cloud_run_service.model_api.status[0].url
}
