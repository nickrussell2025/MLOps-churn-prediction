locals {
    infra = data.terraform_remote_state.infrastructure.outputs
}

# Deploy Grafana first
resource "google_cloud_run_service" "grafana" {
    name     = "grafana-monitoring"
    location = local.infra.region

    template {
        spec {
            service_account_name = local.infra.service_account_email
            containers {
                image = "grafana/grafana:latest"

                resources {
                    limits = {
                        memory = "1Gi"
                        cpu    = "1000m"
                    }
                }

                env {
                    name  = "GF_SERVER_HTTP_PORT"
                    value = "8080"
                }
                env {
                    name  = "GF_SECURITY_ADMIN_PASSWORD"
                    value = var.db_password
                }
                env {
                    name  = "GF_DATABASE_TYPE"
                    value = "postgres"
                }
                env {
                    name  = "GF_DATABASE_HOST"
                    value = "${local.infra.cloud_sql_ip}:5432"
                }
                env {
                    name  = "GF_DATABASE_NAME"
                    value = local.infra.grafana_database_name
                }
                env {
                    name  = "GF_DATABASE_USER"
                    value = local.infra.database_user
                }
                env {
                    name  = "GF_DATABASE_PASSWORD"
                    value = var.db_password
                }
                env {
                    name  = "GF_DATABASE_SSL_MODE"
                    value = "disable"
                }

                ports {
                    container_port = 8080
                }

                # Startup probe ensures Grafana API is ready
                startup_probe {
                    http_get {
                        path = "/api/health"
                        port = 8080
                    }
                    initial_delay_seconds = 10
                    period_seconds        = 5
                    timeout_seconds       = 3
                    failure_threshold     = 12
                }
            }
        }
    }

    traffic {
        percent         = 100
        latest_revision = true
    }
}

resource "google_cloud_run_service_iam_member" "grafana_public" {
    service  = google_cloud_run_service.grafana.name
    location = google_cloud_run_service.grafana.location
    role     = "roles/run.invoker"
    member   = "allUsers"
}

# Wait for Grafana to be fully ready before creating datasource
resource "null_resource" "wait_for_grafana" {
    depends_on = [google_cloud_run_service.grafana]

    provisioner "local-exec" {
        command = "sleep 60"
    }

    triggers = {
        grafana_url = google_cloud_run_service.grafana.status[0].url
    }
}

# Configure Grafana provider - will automatically wait for startup probe
provider "grafana" {
    url  = google_cloud_run_service.grafana.status[0].url
    auth = "admin:${var.db_password}"
}

# Create monitoring datasource automatically with proper dependencies
resource "grafana_data_source" "monitoring_postgres" {
    depends_on = [null_resource.wait_for_grafana]

    type          = "postgres"
    name          = "PostgreSQL-Monitoring"
    url           = "${local.infra.cloud_sql_ip}:5432"
    username      = local.infra.database_user
    database_name = local.infra.monitoring_database_name
    is_default    = true

    json_data_encoded = jsonencode({
        sslmode = "disable"
        postgresVersion = 1400
        timescaledb = false
    })

    secure_json_data_encoded = jsonencode({
        password = var.db_password
    })

    lifecycle {
        create_before_destroy = true
    }
}

# Create folder for dashboards
resource "grafana_folder" "monitoring" {
    depends_on = [null_resource.wait_for_grafana]
    title = "MLOps Monitoring"
}

output "grafana_url" {
    description = "Grafana monitoring dashboard URL"
    value       = google_cloud_run_service.grafana.status[0].url
}

output "datasource_uid" {
    description = "Monitoring datasource UID for dashboards"
    value       = grafana_data_source.monitoring_postgres.uid
}
