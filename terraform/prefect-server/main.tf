locals {
    infra = data.terraform_remote_state.infrastructure.outputs
}

resource "google_cloud_run_service" "prefect_server" {
    name     = "prefect-server"
    location = local.infra.region

    template {
        metadata {
            annotations = {
                "autoscaling.knative.dev/maxScale"         = "5"
                "run.googleapis.com/execution-environment" = "gen2"
            }
        }
        spec {
            service_account_name = local.infra.service_account_email
            containers {
                image = "europe-west2-docker.pkg.dev/mlops-churn-prediction-465023/mlops-repo/prefect-server:latest"

                resources {
                    limits = {
                        memory = "1Gi"
                        cpu    = "1000m"
                    }
                }

                env {
                    name  = "PREFECT_API_DATABASE_CONNECTION_URL"
                    value = "postgresql+asyncpg://${local.infra.database_user}:${var.db_password}@${local.infra.cloud_sql_ip}:5432/prefect"
                }
                env {
                    name  = "GOOGLE_CLOUD_PROJECT"
                    value = local.infra.project_id
                }

                env {
                    name  = "GOOGLE_CLOUD_REGION"
                    value = local.infra.region
                }

                ports {
                    container_port = 8080
                }
                startup_probe {
                    http_get {
                        path = "/api/health"
                        port = 8080
                    }
                    initial_delay_seconds = 20
                    period_seconds        = 5
                    timeout_seconds       = 3
                    failure_threshold     = 15
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

resource "google_cloud_run_service_iam_member" "prefect_public" {
    service  = google_cloud_run_service.prefect_server.name
    location = google_cloud_run_service.prefect_server.location
    role     = "roles/run.invoker"
    member   = "allUsers"
}

output "prefect_server_url" {
    description = "Prefect server URL"
    value       = google_cloud_run_service.prefect_server.status[0].url
}

resource "google_project_iam_member" "prefect_cloud_run_jobs" {
    project = local.infra.project_id
    role    = "roles/run.admin"
    member  = "serviceAccount:${local.infra.service_account_email}"
}
