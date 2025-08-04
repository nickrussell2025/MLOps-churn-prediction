# MLOps Bank Churn Prediction

## Problem Statement

Customer churn is a critical business challenge for banks, where identifying customers likely to leave enables proactive retention strategies. This project implements an end-to-end MLOps pipeline to predict customer churn using machine learning, with a focus on maximising recall to catch as many potential churners as possible. The system processes raw customer data through automated feature engineering and serves predictions via a scalable API.

## Data

Uses the [Bank Customer Churn Modeling dataset from Kaggle](https://www.kaggle.com/datasets/shrutimechlearn/churn-modelling) with customer features: credit score, geography, gender, age, tenure, balance, products, activity status, and estimated salary.

## Architecture

**Development Environment:**
- PostgreSQL database (Docker) for local testing
- MLflow tracking server (local SQLite) for experimentation
- Prefect orchestration server (local) for pipeline development
- Flask API with feature engineering pipeline

**Production (GCP) - Serverless Cloud-Native:**
- Cloud SQL PostgreSQL for data storage
- MLflow on Cloud Run for experiment tracking
- Prefect on Cloud Run for workflow orchestration
- Model API on Cloud Run for serving predictions
- Grafana on Cloud Run for monitoring and dashboards
- Infrastructure managed with Terraform (5 modules)
- Automated CI/CD with GitHub Actions

## Alignment with Project Brief

**Cloud**
- Complete GCP deployment using Terraform Infrastructure as Code
- Cloud Run serverless architecture with auto-scaling
- Cloud SQL managed database with automated backups
- GCS object storage for ML artifacts and reference data

**Experiment Tracking & Model Registry**
- MLflow deployed on Cloud Run with PostgreSQL backend
- All experiments tracked with parameters, metrics, and artifacts
- Model registry with versioning and production aliases
- Automatic model loading in API from registry

**Workflow Orchestration**
- Prefect Server deployed on Cloud Run
- Training pipeline containerized for Cloud Run Jobs
- Serverless workflow execution with automatic scaling
- Work pools and deployments properly configured

**Model Deployment**
- Flask API containerized and deployed to Cloud Run
- Automatic model loading from MLflow registry
- Health checks and startup probes for reliability
- Prediction logging to database for monitoring

**Model Monitoring**
- Grafana deployed with automated database configuration
- Prediction logging for all API requests
- Drift detection using Evidently framework - MANUAL ONLY

**Reproducibility**
- Local reproducibility but hardcoded values remain in the system - SEE KNOWN ISSUES BELOW 
- Complete Terraform automation with 5 infrastructure modules
- All dependencies managed by UV with locked versions

**Best Practices**
- Makefile for automation and developer productivity
- Ruff linter and formatter with pre-commit hooks
- Test suite with pytest
- GitHub Actions CI/CD pipeline for automated deployment
- Health monitoring scripts for system validation

## Known Issues

### Hardcoded Configuration Values
This implementation contains several hardcoded values that would need to be parameterized for production deployment:

- **Prefect Server URL**: Hardcoded in `Dockerfile.prefect-server`
- **GCP Project ID**: Hardcoded throughout Terraform configurations  
- **Container Registry**: Hardcoded to specific project in Makefiles
- **GitHub Repository URLs**: Hardcoded in `prefect.yaml` and environment templates

### Production Recommendations
For production deployment, these should be:
- Parameterized using Terraform variables
- Configured via environment-specific config files
- Managed through CI/CD pipeline variables
- Set via Kubernetes ConfigMaps/Secrets (if using GKE)

**Terraform URL Output Mismatch:**
- Cloud Run services work correctly but terraform outputs show outdated URL formats
- Affects MLflow and Model API terraform outputs only
- **Workaround:** Hardcoded correct URLs in model-api configuration
- **Impact:** None on functionality - all services operational
- **Root Cause:** GCP generates multiple URL formats, terraform caches legacy format
- **Future Fix:** Replace terraform outputs with data sources for real-time URL lookup

**Grafana Dashboard Configuration:**
- Grafana service deploys successfully but dashboards require manual import
- **Workaround:** Access Grafana UI and manually import dashboard JSON files
- **Impact:** Monitoring data available, visualizations need manual setup
- **Future Fix:** Automate dashboard provisioning via terraform


## Quick Start

### Prerequisites

- Python 3.11+
- Docker & Docker Compose
- UV package manager (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
- Terraform (`apt install terraform` or equivalent)
- Google Cloud CLI (`curl https://sdk.cloud.google.com | bash`)

### VM Development Environment Setup

**Create GCP VM for development:**

```bash
# Create development VM
gcloud compute instances create mlops-dev-vm \
    --zone=europe-west2-a \
    --machine-type=e2-standard-2 \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=50GB \
    --scopes=cloud-platform

# SSH to VM
gcloud compute ssh mlops-dev-vm --zone=europe-west2-a

# Install dependencies on VM
sudo apt update && sudo apt upgrade -y
sudo apt install -y make curl git jq

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install UV package manager
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update && sudo apt install terraform

# Clone repository
git clone https://github.com/nickrussell2025/MLOps-churn-prediction.git
cd mlops-project

# Install project dependencies
uv sync --all-extras
```

### Authentication Setup

**Use Compute Engine default service account (recommended):**

```bash
# Set to use compute service account (has Editor permissions)
gcloud config set account $(gcloud config get-value core/account | grep compute@developer.gserviceaccount.com)
gcloud config set project your-gcp-project-id

# Verify authentication
gcloud projects describe your-gcp-project-id
```

### Local Development

```bash
# Setup local environment
cp .env.template .env.local
make install

# Start local services
make run-local

# Run training pipeline
make run-pipeline

# Start API
make run-api
```

**Local Services:**
- API: http://localhost:8080
- MLflow: http://localhost:5000
- Adminer: http://localhost:8081 (postgres/example/monitoring)

### Cloud Deployment

**Create environment configuration:**

```bash
# Create .tfvars files for all modules
cat > terraform/infrastructure/terraform.tfvars << 'EOF'
project_id = "your-gcp-project-id"
db_password = "your-secure-database-password"
EOF

cat > terraform/services/terraform.tfvars << 'EOF'
db_password = "your-secure-database-password"
EOF

cat > terraform/model-api/terraform.tfvars << 'EOF'
db_password = "your-secure-database-password"
EOF

cat > terraform/prefect-server/terraform.tfvars << 'EOF'
db_password = "your-secure-database-password"
EOF

cat > terraform/monitoring/terraform.tfvars << 'EOF'
db_password = "your-secure-database-password"
grafana_readonly_password = "your-secure-grafana-password"
EOF

# Create environment file (update with your actual values)
cat > .env.cloud << 'EOF'
GOOGLE_CLOUD_PROJECT=your-gcp-project-id
GOOGLE_CLOUD_REGION=europe-west2
DATABASE_HOST=your-database-ip
DATABASE_PORT=5432
DATABASE_USER=postgres
DATABASE_PASSWORD=your-secure-database-password
DATABASE_NAME=monitoring
MLFLOW_TRACKING_URI=https://your-mlflow-url
MODEL_API_URL=https://your-model-api-url
PREFECT_API_URL=https://your-prefect-url/api
GRAFANA_URL=https://your-grafana-url
EOF

# Fix script permissions (required after git clone)
chmod +x update-environment.sh test-endpoints.sh

# Deploy all components
make deploy-all

# Test system health
make test-system
```

### Training Pipeline Execution

```bash
# Deploy training pipeline configuration
make deploy-training

# Start Prefect worker (keep running)
make start-worker

# Execute training pipeline
make run-training
```

## Live Demo Testing

**Test the live model API endpoint:**

```bash
curl -X POST https://model-api-139798376302.europe-west2.run.app/predict \
  -H "Content-Type: application/json" \
  -d '{
    "CreditScore": 750,
    "Geography": "Germany",
    "Gender": "Male",
    "Age": 40,
    "Tenure": 8,
    "Balance": 100000.0,
    "NumOfProducts": 1,
    "HasCrCard": 1,
    "IsActiveMember": 0,
    "EstimatedSalary": 80000.0
  }'
```

**Expected Response:**
```json
{
  "model_version": "2",
  "prediction": 1,
  "probability": 0.7696,
  "timestamp": "2025-08-04T13:56:12.375087"
}
```

## Development Commands

**Local Development:**
```bash
make install        # Install dependencies
make test           # Run tests
make lint           # Check code quality
make format         # Format code
make run-pipeline   # Train model locally
make run-api        # Start local API
```

**Cloud Operations:**
```bash
make build-containers   # Build and push containers
make deploy-infra       # Deploy infrastructure
make deploy-services    # Deploy MLflow
make deploy-api         # Deploy model API
make deploy-monitoring  # Deploy Grafana
make test-system        # Test all endpoints
make teardown           # Destroy infrastructure
```

**Training Pipeline:**
```bash
make deploy-training  # Setup training pipeline
make start-worker     # Start Prefect worker
make run-training     # Execute training
```

### Terraform Modules

1. **Infrastructure** - Core resources (database, storage, service accounts)
2. **Services** - MLflow tracking server deployment
3. **Model-API** - Flask API service deployment
4. **Prefect-Server** - Workflow orchestration deployment
5. **Monitoring** - Grafana dashboard deployment

## GitHub Actions CI/CD

**Testing Workflow (.github/workflows/test.yml):**
- Triggers on pull requests
- Executes ruff linting for code quality
- Validates container builds

**Deployment Workflow (.github/workflows/deploy.yml):**
- Triggers on main branch pushes
- Builds containers with Git SHA tagging
- Deploys to Cloud Run automatically

**Setup Requirements:**
- GCP_PROJECT_ID secret
- GCP_SA_KEY secret (base64-encoded service account key)
- DATABASE_PASSWORD secret

## Authentication and Permissions

**VM Development Authentication:**
```bash
# Use Compute Engine default service account (automatic Editor permissions)
gcloud config set account $(gcloud config get-value core/account | grep compute@developer.gserviceaccount.com)
gcloud config set project your-gcp-project-id
```

**Why this works:**
- Compute service account automatically has Editor permissions
- No manual IAM setup required
- Consistent across all GCP projects

**For teardown operations:** Compute service account has sufficient permissions for all infrastructure operations including service deletion and IAM policy management.

## Monitoring and Observability

**System Health Monitoring:**
```bash
# Test all service endpoints
make test-system
```

**Database Monitoring:**
- All predictions logged to monitoring.predictions table
- Drift detection results in monitoring.drift_reports table
- MLflow experiments in mlflow database
- Prefect metadata in prefect database

## Project Structure

```
mlops-project/
├── src/mlops_churn/           # Application code
│   ├── churn_pipeline.py      # Training pipeline
│   ├── app.py                 # Flask API
│   ├── database.py            # Database utilities
│   └── models/                # Model artifacts
├── terraform/                 # Infrastructure as Code
│   ├── infrastructure/        # Core resources
│   ├── services/              # MLflow deployment
│   ├── model-api/             # API deployment
│   ├── prefect-server/        # Orchestration deployment
│   └── monitoring/            # Grafana deployment
├── .github/workflows/         # CI/CD pipelines
├── tests/                     # Test suite
├── data/raw/                  # Training data
├── docker-compose.yml         # Local services
├── Makefile                   # Cross-platform automation
└── README.md                  # This file
```

## Reproducibility Notes

**Complete System Reproducibility:**
1. Create GCP VM with compute service account (automatic Editor permissions)
2. Clone repository and install dependencies
3. Create .tfvars files with project-specific values
4. Run `make deploy-all` for complete infrastructure deployment
5. Execute `make test-system` to validate all services

**No manual permission setup required** - Compute Engine default service account provides all necessary permissions for infrastructure operations.

**Cross-Platform Compatibility:**
- Makefile works on Linux, macOS, and Windows (with appropriate shells)
- No PowerShell dependencies in core automation
- Docker-based local development for consistency

## Further Development

Future enhancements would focus on making this a general-purpose machine learning platform that works with any type of data and model. Key improvements include:

- **Enhanced Monitoring:** Custom Grafana dashboards with alerting rules
- **Advanced ML Operations:** A/B testing framework and champion/challenger patterns
- **Production Hardening:** Rate limiting, API security, and comprehensive logging
- **Multi-Environment Support:** Development, staging, and production environments
- **Performance Optimization:** Load testing and resource optimization
- **Advanced Testing:** Integration tests and performance benchmarks
