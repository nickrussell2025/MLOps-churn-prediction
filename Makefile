# MLOps Bank Churn - Cross-Platform Makefile (Bash Only)

.PHONY: help install test lint format clean run-local run-api run-mlflow run-prefect run-pipeline build-containers deploy-infra deploy-services deploy-prefect deploy-api deploy-monitoring deploy-training run-training start-worker deploy-all test-endpoints test-system teardown

help:
	@echo "Essential Commands:"
	@echo "  install          - Install dependencies"
	@echo "  test             - Run tests"
	@echo "  lint             - Check code quality"
	@echo "  format           - Format code"
	@echo "  build-containers - Build and push all containers"
	@echo "  deploy-infra     - Deploy infrastructure"
	@echo "  deploy-services  - Deploy MLflow"
	@echo "  deploy-prefect   - Deploy Prefect"
	@echo "  deploy-api       - Deploy API"
	@echo "  deploy-monitoring- Deploy Grafana"
	@echo "  deploy-training  - Deploy training pipeline"
	@echo "  run-training     - Run training job"
	@echo "  start-worker     - Start Prefect worker"
	@echo "  deploy-all       - Deploy everything"
	@echo "  test-endpoints   - Test service health"
	@echo "  test-system      - Full system health check"
	@echo "  teardown         - Destroy everything"

# SETUP
install:
	uv sync --all-extras

# DEVELOPMENT
test:
	uv run pytest tests/ -v

lint:
	uv run ruff check src tests

format:
	uv run ruff format src tests

# LOCAL SERVICES
run-local:
	docker-compose up -d

run-api:
	uv run python -m src.mlops_churn.app

run-mlflow:
	uv run mlflow ui --backend-store-uri sqlite:///mlflow.db --default-artifact-root ./mlruns --port 5000

run-prefect:
	uv run prefect server start --host 127.0.0.1 --port 4200

run-pipeline:
	uv run python -m src.mlops_churn.churn_pipeline

# ENVIRONMENT MANAGEMENT
update-environment:
	./update-environment.sh

# DEPLOYMENT - DYNAMIC PROJECT ID (NO HARDCODING)
build-containers:
	@echo "Building and pushing all containers..."
	$(eval PROJECT_ID=$(shell gcloud config get-value project))
	@echo "Using project: $(PROJECT_ID)"
	gcloud auth configure-docker europe-west2-docker.pkg.dev
	docker build -f Dockerfile.model-api -t europe-west2-docker.pkg.dev/$(PROJECT_ID)/mlops-repo/model-api:latest .
	docker build -f Dockerfile.prefect-server -t europe-west2-docker.pkg.dev/$(PROJECT_ID)/mlops-repo/prefect-server:latest .
	docker build -f Dockerfile.training -t europe-west2-docker.pkg.dev/$(PROJECT_ID)/mlops-repo/training-pipeline:latest .
	docker push europe-west2-docker.pkg.dev/$(PROJECT_ID)/mlops-repo/model-api:latest
	docker push europe-west2-docker.pkg.dev/$(PROJECT_ID)/mlops-repo/prefect-server:latest
	docker push europe-west2-docker.pkg.dev/$(PROJECT_ID)/mlops-repo/training-pipeline:latest

deploy-infra:
	cd terraform/infrastructure && terraform init && terraform apply -auto-approve
	$(MAKE) update-environment

deploy-services:
	cd terraform/services && terraform init && terraform apply -auto-approve

deploy-prefect:
	cd terraform/prefect-server && terraform init && terraform apply -auto-approve

deploy-api:
	cd terraform/model-api && terraform init && terraform apply -auto-approve

deploy-monitoring:
	cd terraform/monitoring && terraform init && terraform apply -auto-approve

# TRAINING PIPELINE - BASH SYNTAX ONLY
deploy-training:
	@PREFECT_URL=$$(gcloud run services describe prefect-server --region=europe-west2 --format="value(status.url)") && \
	export PREFECT_API_URL="$$PREFECT_URL/api" && \
	uv run prefect work-pool create cloud-run-jobs --type cloud-run-v2 --overwrite && \
	uv run python deploy_with_deps.py

run-training:
	@PREFECT_URL=$$(gcloud run services describe prefect-server --region=europe-west2 --format="value(status.url)") && \
	export PREFECT_API_URL="$$PREFECT_URL/api" && \
	uv run prefect deployment run 'churn-prediction-pipeline/churn-pipeline-cloud-run'

start-worker:
	@PREFECT_URL=$$(gcloud run services describe prefect-server --region=europe-west2 --format="value(status.url)") && \
	export PREFECT_API_URL="$$PREFECT_URL/api" && \
	uv run prefect worker start --pool cloud-run-jobs

# CLOUD TESTING
test-cloud-pipeline:
	@cp .env.cloud .env
	@uv run python -m src.mlops_churn.churn_pipeline
	@rm .env

test-cloud-api:
	@cp .env.cloud .env
	@uv run python -m src.mlops_churn.app
	@rm .env

# TESTING
test-endpoints:
	@chmod +x test-endpoints.sh && ./test-endpoints.sh

test-system: test-endpoints
	@echo "Full system health check completed"

# COMPLETE DEPLOYMENT
deploy-all: deploy-infra build-containers deploy-services deploy-prefect deploy-api deploy-monitoring deploy-training
	@echo "Complete MLOps infrastructure deployed!"
	@echo "Environment files updated automatically by deploy-infra"
	@echo "To run training: make start-worker (terminal 1) then make run-training (terminal 2)"

# TEARDOWN
teardown-api:
	cd terraform/model-api && terraform destroy -auto-approve

teardown-monitoring:
	cd terraform/monitoring && terraform destroy -auto-approve

teardown-prefect:
	cd terraform/prefect-server && terraform destroy -auto-approve

teardown-services:
	cd terraform/services && terraform destroy -auto-approve

teardown-infra:
	cd terraform/infrastructure && terraform destroy -auto-approve

teardown: teardown-api teardown-prefect teardown-services teardown-monitoring teardown-infra

# CLEANUP
clean:
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
