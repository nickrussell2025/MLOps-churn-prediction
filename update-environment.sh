#!/bin/bash
# Update Environment Configuration from Terraform Outputs
# Purpose: Automatically update environment files with current infrastructure values
# Usage: ./update-environment.sh

set -e

echo "Updating environment configuration from Terraform outputs..."

# Get current project info
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# Get Terraform outputs from infrastructure
echo "Getting infrastructure outputs..."
cd terraform/infrastructure

CLOUD_SQL_IP=$(terraform output -raw cloud_sql_ip)
BUCKET_NAME=$(terraform output -raw artifacts_bucket_name)
SERVICE_ACCOUNT=$(terraform output -raw service_account_email)

cd ../..

# Get service URLs dynamically
echo "Getting service URLs..."
MLFLOW_URL="https://mlflow-working-${PROJECT_NUMBER}.europe-west2.run.app"
MODEL_API_URL="https://model-api-${PROJECT_NUMBER}.europe-west2.run.app"
GRAFANA_URL=$(gcloud run services describe grafana-monitoring --region=europe-west2 --format="value(status.url)" 2>/dev/null || echo "")
PREFECT_URL=$(gcloud run services describe prefect-server --region=europe-west2 --format="value(status.url)" 2>/dev/null || echo "")

# Update .env.cloud with current values
echo "Updating .env.cloud..."
cat > .env.cloud << EOF
# Cloud Environment Configuration
# Auto-generated: $(date)
# Run ./update-environment.sh to refresh after infrastructure changes

# GCP Configuration
GOOGLE_CLOUD_PROJECT=${PROJECT_ID}
GOOGLE_CLOUD_REGION=europe-west2

# Database Configuration (from Terraform outputs)
DATABASE_HOST=${CLOUD_SQL_IP}
DATABASE_PORT=5432
DATABASE_USER=postgres
DATABASE_PASSWORD=mlflow123secure
DATABASE_NAME=monitoring

# MLflow Configuration
MLFLOW_TRACKING_URI=${MLFLOW_URL}
MLFLOW_DEFAULT_ARTIFACT_ROOT=gs://${BUCKET_NAME}

# Storage Configuration
USE_CLOUD_STORAGE=true
BUCKET_NAME=${BUCKET_NAME}
CLOUD_REFERENCE_PATH=reference/reference_data.parquet

# Service URLs
MODEL_API_URL=${MODEL_API_URL}
GRAFANA_URL=${GRAFANA_URL}
PREFECT_API_URL=${PREFECT_URL}/api

# Model Configuration
MODEL_NAME=bank-churn-classifier
MODEL_ALIAS=production

# API Configuration
API_HOST=0.0.0.0
API_PORT=8080

# Service Account
SERVICE_ACCOUNT_EMAIL=${SERVICE_ACCOUNT}

# Container Registry
CONTAINER_REGISTRY=europe-west2-docker.pkg.dev
REPOSITORY_NAME=mlops-repo
EOF

echo "Environment updated successfully!"
echo ""
echo "Current Configuration:"
echo "  Project ID: ${PROJECT_ID}"
echo "  Database IP: ${CLOUD_SQL_IP}"
echo "  MLflow URL: ${MLFLOW_URL}"
echo "  Model API: ${MODEL_API_URL}"
echo "  Grafana: ${GRAFANA_URL}"
echo ""
echo "To use: export MLOPS_ENV=cloud"
