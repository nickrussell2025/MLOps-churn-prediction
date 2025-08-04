# infrastructure/main.tf - Stable foundation (database, storage, IAM)

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  backend "gcs" {
    bucket = "mlops-churn-prediction-465023-terraform-state"  # harcoded for back end
    prefix = "infrastructure/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "mlflow_db" {
  name             = "mlflow-db-v2"
  database_version = "POSTGRES_14"
  region           = var.region

  settings {
    tier = "db-f1-micro"

    database_flags {
      name  = "max_connections"
      value = "50"
    }

    database_flags {
      name  = "idle_in_transaction_session_timeout"
      value = "300000"
    }

    database_flags {
    name  = "tcp_keepalives_idle"
    value = "600"
    }

    database_flags {
    name  = "tcp_keepalives_interval"
    value = "30"
    }

    database_flags {
    name  = "tcp_keepalives_count"
    value = "3"
    }

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "allow-all"
        value = "0.0.0.0/0"
      }
    }

    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }

    disk_autoresize = true
    disk_size       = 20
    disk_type       = "PD_SSD"
  }

  deletion_protection = false
}

resource "google_sql_database" "mlflow" {
    name     = "mlflow"
    instance = google_sql_database_instance.mlflow_db.name
    deletion_policy = "ABANDON"
    depends_on = [google_sql_database_instance.mlflow_db]
}

resource "google_sql_database" "monitoring" {
    name     = "monitoring"
    instance = google_sql_database_instance.mlflow_db.name
    deletion_policy = "ABANDON"
    depends_on = [google_sql_database_instance.mlflow_db]
}

resource "google_sql_database" "prefect" {
    name     = "prefect"
    instance = google_sql_database_instance.mlflow_db.name
    deletion_policy = "ABANDON"
    depends_on = [google_sql_database_instance.mlflow_db]
}

resource "google_sql_database" "grafana" {
    name            = "grafana"
    instance        = google_sql_database_instance.mlflow_db.name
    deletion_policy = "ABANDON"
    depends_on      = [google_sql_database_instance.mlflow_db]
}

resource "google_sql_user" "mlflow_user" {
    name     = "postgres"
    instance = google_sql_database_instance.mlflow_db.name
    password = var.db_password
    deletion_policy = "ABANDON"
    depends_on = [google_sql_database_instance.mlflow_db]

}

# GCS Bucket for MLflow Artifacts
resource "google_storage_bucket" "mlflow_artifacts" {
  name     = "${var.project_id}-mlflow-artifacts"
  location = var.region

  force_destroy = true

  versioning {
    enabled = true
  }
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
  uniform_bucket_level_access = true
}

# Service Account for Cloud Run Services
resource "google_service_account" "cloud_run_sa" {
  account_id   = "mlops-cloud-run-sa"
  display_name = "MLOps Cloud Run Service Account"
}

resource "google_storage_bucket_iam_member" "artifacts_access" {
  bucket = google_storage_bucket.mlflow_artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "cloud_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "artifactregistry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "service_account_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_artifact_registry_repository" "mlops_repo" {
  repository_id = "mlops-repo"
  location      = var.region
  format        = "DOCKER"
  description   = "MLOps container images"
}

resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}


resource "google_project_iam_member" "storage_admin_terraform" {
    project = var.project_id
    role    = "roles/storage.admin"
    member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "storage_object_admin" {
    project = var.project_id
    role    = "roles/storage.objectAdmin"
    member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}
