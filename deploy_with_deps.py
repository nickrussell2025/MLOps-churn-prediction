import os

from src.mlops_churn.churn_pipeline import churn_prediction_pipeline

# Get current project automatically
project_id = os.popen("gcloud config get-value project").read().strip()

if __name__ == "__main__":
    churn_prediction_pipeline.deploy(
        name="churn-pipeline-cloud-run",
        work_pool_name="cloud-run-jobs",
        image=f"europe-west2-docker.pkg.dev/{project_id}/mlops-repo/training-pipeline:latest",
        build=None,
        job_variables={
            "env": {
                "MLFLOW_TRACKING_URI": "https://mlflow-working-139798376302.europe-west2.run.app",
                "DATABASE_URL": "postgresql://postgres:mlflow123secure@34.39.46.29:5432/monitoring",
                "USE_CLOUD_STORAGE": "true",
                "BUCKET_NAME": f"{project_id}-mlflow-artifacts",
            },
            "cpu": "4",
            "memory": "8Gi",
        },
    )
