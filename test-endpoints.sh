#!/bin/bash

echo "Testing MLOps Service Endpoints"

curl --max-time 30 --silent --fail https://model-api-139798376302.europe-west2.run.app/ > /dev/null && echo "Model API: HEALTHY" || echo "Model API: FAILED"

curl --max-time 30 --silent --fail https://mlflow-working-139798376302.europe-west2.run.app/ > /dev/null && echo "MLflow: HEALTHY" || echo "MLflow: FAILED"

curl --max-time 30 --silent --fail https://prefect-server-139798376302.europe-west2.run.app/ > /dev/null && echo "Prefect: HEALTHY" || echo "Prefect: FAILED"

curl --max-time 30 --silent https://grafana-monitoring-139798376302.europe-west2.run.app/ > /dev/null && echo "Grafana: HEALTHY" || echo "Grafana: FAILED"

echo "Health check complete"
