import os
import subprocess
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(".env.cloud" if os.getenv("MLOPS_ENV") == "cloud" else ".env.local")
load_dotenv()


def get_database_host():
    """Get current Cloud SQL IP address dynamically"""
    try:
        # Get instance name dynamically from project
        project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        if not project_id:
            return os.getenv("DATABASE_HOST", "localhost")

        result = subprocess.run(
            [
                "gcloud",
                "sql",
                "instances",
                "list",
                "--format=value(name)",
                "--filter=name:mlflow*",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )

        if result.returncode != 0 or not result.stdout.strip():
            return os.getenv("DATABASE_HOST", "localhost")

        instance_name = result.stdout.strip().split("\n")[0]

        # Get IP for the found instance
        result = subprocess.run(
            [
                "gcloud",
                "sql",
                "instances",
                "describe",
                instance_name,
                "--format=value(ipAddresses[0].ipAddress)",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )

        if result.returncode == 0:
            return result.stdout.strip()
        else:
            return os.getenv("DATABASE_HOST", "localhost")
    except (subprocess.SubprocessError, FileNotFoundError, Exception):
        return os.getenv("DATABASE_HOST", "localhost")


class Config:
    PROJECT_ROOT = Path(__file__).parent.parent.parent
    DATA_DIR = PROJECT_ROOT / "data"
    MODELS_DIR = PROJECT_ROOT / "models"

    MODEL_NAME = os.getenv("MODEL_NAME", "bank-churn-classifier")
    MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
    MODEL_ALIAS = os.getenv("MODEL_ALIAS", "production")
    API_HOST = os.getenv("API_HOST", "0.0.0.0")
    API_PORT = int(os.getenv("API_PORT", "8080"))

    # Add this line
    MODEL_API_URL = os.getenv(
        "MODEL_API_URL",
        f"https://model-api-{os.getenv('GOOGLE_CLOUD_PROJECT', 'unknown')}.europe-west2.run.app",
    )

    # Database config - DYNAMIC IP RESOLUTION
    DATABASE_HOST = get_database_host()
    DATABASE_PORT = os.getenv("DATABASE_PORT", "5432")
    DATABASE_NAME = os.getenv("DATABASE_NAME", "monitoring")
    DATABASE_USER = os.getenv("DATABASE_USER", "postgres")
    DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD", "example")

    USE_CLOUD_STORAGE = os.getenv("USE_CLOUD_STORAGE", "false").lower() == "true"
    BUCKET_NAME = os.getenv(
        "BUCKET_NAME", f"{os.getenv('GOOGLE_CLOUD_PROJECT', 'local')}-mlflow-artifacts"
    )
    LOCAL_REFERENCE_PATH = os.getenv(
        "LOCAL_REFERENCE_PATH", "monitoring/reference_data.parquet"
    )
    CLOUD_REFERENCE_PATH = os.getenv(
        "CLOUD_REFERENCE_PATH", "reference/reference_data.parquet"
    )


config = Config()
