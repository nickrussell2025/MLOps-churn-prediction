import warnings
from datetime import datetime, timedelta

import numpy as np
import pandas as pd
import psycopg2
from evidently import DataDefinition, Dataset, Report
from evidently.presets import DataDriftPreset

warnings.filterwarnings("ignore", category=RuntimeWarning)
np.seterr(divide="ignore", invalid="ignore")


from .config import config
from .database import log_drift_result

DB_CONN = {
    "host": config.DATABASE_HOST,
    "port": config.DATABASE_PORT,
    "database": config.DATABASE_NAME,
    "user": config.DATABASE_USER,
    "password": config.DATABASE_PASSWORD,
}


def get_recent_predictions():
    """Get recent prediction data from database"""
    with psycopg2.connect(**DB_CONN) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT input_data FROM predictions WHERE timestamp >= %s ORDER BY timestamp DESC LIMIT 50",
                [datetime.now() - timedelta(days=7)],
            )
            rows = cur.fetchall()
            return pd.DataFrame([row[0] for row in rows]) if len(rows) >= 10 else None


def load_reference_data():
    if config.USE_CLOUD_STORAGE:
        return pd.read_parquet(
            f"gs://{config.BUCKET_NAME}/{config.CLOUD_REFERENCE_PATH}"
        )
    else:
        return pd.read_parquet(config.LOCAL_REFERENCE_PATH)


def detect_drift():
    """Main drift detection function"""
    # Load reference data
    reference_df = load_reference_data()

    # Get current predictions
    current_df = get_recent_predictions()
    if current_df is None:
        return False

    # Fix categorical data types
    if "Gender" in reference_df.columns and "Gender" in current_df.columns:
        reference_df["Gender"] = reference_df["Gender"].astype("object")
        current_df["Gender"] = current_df["Gender"].astype("object")

    # Define schema based on actual columns
    numerical_columns = [
        "CreditScore",
        "Age",
        "Tenure",
        "Balance",
        "NumOfProducts",
        "EstimatedSalary",
        "BalanceActivityInteraction",
        "HasCrCard",
        "IsActiveMember",
        "ZeroBalance",
        "UnderUtilized",
        "AgeRisk",
        "GermanyRisk",
        "GermanyMatureCombo",
    ]
    categorical_columns = ["Gender"]

    schema = DataDefinition(
        numerical_columns=numerical_columns,
        categorical_columns=categorical_columns,
    )

    # Run drift detection
    report = Report([DataDriftPreset()])
    result = report.run(
        Dataset.from_pandas(current_df, data_definition=schema),
        Dataset.from_pandas(reference_df, data_definition=schema),
    )

    # Extract results
    drift_data = result.dict()["metrics"][0]["value"]
    drift_share = round(float(drift_data["share"]), 3)
    drifted_columns = int(drift_data["count"])
    dataset_drift = drift_share > 0.5

    # Log results
    # log_drift_result(dataset_drift, drift_share, drifted_columns, len(current_df))
    log_drift_result(
        dataset_drift,
        drift_share,
        feature_name=f"{drifted_columns}_columns_drifted",
        drift_type="data_drift",
        report_data={
            "drifted_columns": drifted_columns,
            "drift_share": drift_share,
            "sample_size": len(current_df),
        },
    )

    print(
        f"DRIFT DETECTED! {drifted_columns} columns drifted, share: {drift_share}"
        if dataset_drift
        else f"No drift. Share: {drift_share}"
    )
    return True


if __name__ == "__main__":
    detect_drift()
