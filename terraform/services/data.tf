terraform {
    required_version = ">= 1.0"
    required_providers {
        google = {
            source  = "hashicorp/google"
            version = "~> 6.0"
        }
    }
    backend "gcs" {
        bucket = "mlops-churn-prediction-465023-terraform-state"
        prefix = "services/state"  # CHANGED: was "mlflow/state"
    }
}

# Import infrastructure outputs
data "terraform_remote_state" "infrastructure" {
    backend = "gcs"
    config = {
        bucket = "mlops-churn-prediction-465023-terraform-state"
        prefix = "infrastructure/state"
    }
}

provider "google" {
    project = data.terraform_remote_state.infrastructure.outputs.project_id
    region  = data.terraform_remote_state.infrastructure.outputs.region
}

variable "db_password" {
    description = "Database password"
    type        = string
    sensitive   = true
}
