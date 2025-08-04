import logging
from datetime import datetime

import mlflow
import pandas as pd
from flask import Flask, jsonify, request
from mlflow.tracking import MlflowClient
from pydantic import BaseModel, ValidationError

from .config import config
from .database import initialize_database, log_prediction

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class RawCustomerData(BaseModel):
    CreditScore: float
    Geography: str
    Gender: str
    Age: float
    Tenure: float
    Balance: float
    NumOfProducts: float
    HasCrCard: float
    IsActiveMember: float
    EstimatedSalary: float


def prepare_features(customer_data: dict) -> pd.DataFrame:
    """Apply feature engineering pipeline to raw customer data"""

    df = pd.DataFrame([customer_data])

    # Essential columns validation
    required_cols = [
        "CreditScore",
        "Geography",
        "Gender",
        "Age",
        "Tenure",
        "Balance",
        "NumOfProducts",
        "HasCrCard",
        "IsActiveMember",
        "EstimatedSalary",
    ]

    missing_cols = [col for col in required_cols if col not in df.columns]
    if missing_cols:
        raise ValueError(f"Missing required columns: {missing_cols}")

    clean_df = df[required_cols].copy()

    # Data type conversions
    try:
        clean_df["Geography"] = clean_df["Geography"].astype("category")
        clean_df["Gender"] = clean_df["Gender"].astype("category")

        numeric_cols = [
            "CreditScore",
            "Age",
            "Tenure",
            "Balance",
            "NumOfProducts",
            "HasCrCard",
            "IsActiveMember",
            "EstimatedSalary",
        ]

        for col in numeric_cols:
            clean_df[col] = clean_df[col].astype("float64")

    except (ValueError, TypeError) as e:
        raise ValueError(f"Data type conversion failed: {str(e)}") from e

    # Feature engineering
    clean_df["BalanceActivityInteraction"] = (
        clean_df["Balance"] * clean_df["IsActiveMember"]
    )
    clean_df["ZeroBalance"] = (clean_df["Balance"] == 0).astype("float64")
    clean_df["UnderUtilized"] = (clean_df["NumOfProducts"] == 1).astype("float64")
    clean_df["AgeRisk"] = ((clean_df["Age"] >= 50) & (clean_df["Age"] <= 65)).astype(
        "float64"
    )
    clean_df["GermanyRisk"] = (clean_df["Geography"] == "Germany").astype("float64")
    clean_df["GermanyMatureCombo"] = (
        clean_df["GermanyRisk"] * clean_df["AgeRisk"]
    ).astype("float64")

    # Remove Geography column after feature engineering
    clean_df.drop("Geography", axis=1, inplace=True)

    return clean_df


def create_app():
    app = Flask(__name__)

    if not initialize_database():
        raise RuntimeError("Database initialization failed")

    mlflow.set_tracking_uri(config.MLFLOW_TRACKING_URI)

    # Load model on startup
    try:
        model_uri = f"models:/{config.MODEL_NAME}@{config.MODEL_ALIAS}"
        app.model = mlflow.sklearn.load_model(model_uri)
        app.model_loaded = True

        client = MlflowClient()
        mv = client.get_model_version_by_alias(config.MODEL_NAME, config.MODEL_ALIAS)
        app.model_version = mv.version

        print(f"✅ Model loaded: {model_uri} - version {app.model_version}")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        app.model = None
        app.model_loaded = False
        app.model_version = "unknown"

    @app.route("/")
    def health_check():
        return jsonify(
            {
                "status": "healthy",
                "service": "bank-churn-prediction-api",
                "model_name": config.MODEL_NAME,
                "model_loaded": app.model_loaded,
                "timestamp": datetime.now().isoformat(),
            }
        )

    @app.route("/refresh-model", methods=["POST"])
    def refresh_model():
        """Reload model from MLflow registry"""
        try:
            model_uri = f"models:/{config.MODEL_NAME}@{config.MODEL_ALIAS}"
            app.model = mlflow.sklearn.load_model(model_uri)

            client = MlflowClient()
            mv = client.get_model_version_by_alias(
                config.MODEL_NAME, config.MODEL_ALIAS
            )
            app.model_version = mv.version
            app.model_loaded = True

            return jsonify({"status": "success", "model_version": app.model_version})
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)}), 500

    @app.route("/predict", methods=["POST"])
    def predict():
        """Accepts raw customer data and applies feature engineering before prediction"""

        if not app.model_loaded:
            return jsonify({"error": "Model not loaded"}), 500

        try:
            request_data = request.get_json()
            if not request_data:
                return jsonify({"error": "No JSON data provided"}), 400

            # Validate raw input
            try:
                raw_customer_data = RawCustomerData(**request_data)
            except ValidationError as e:
                return jsonify({"error": "Invalid raw data", "details": str(e)}), 400

            # Apply feature engineering
            try:
                processed_df = prepare_features(raw_customer_data.model_dump())
            except (ValueError, KeyError) as e:
                logger.error(f"Feature engineering failed: {str(e)}")
                return jsonify(
                    {"error": "Feature engineering failed", "details": str(e)}
                ), 400

            # Make prediction
            try:
                prediction = app.model.predict(processed_df)[0]
                probability = app.model.predict_proba(processed_df)[0][1]
            except Exception as e:
                logger.error(f"Model prediction failed: {str(e)}")
                return jsonify(
                    {"error": "Model prediction failed", "details": str(e)}
                ), 500

            # Log to database
            model_version = getattr(app, "model_version", "unknown")
            log_success = log_prediction(
                raw_customer_data.model_dump(), float(probability), model_version
            )

            if not log_success:
                logger.warning("Failed to log prediction to database")

            return jsonify(
                {
                    "prediction": int(prediction),
                    "probability": round(float(probability), 4),
                    "model_version": model_version,
                    "timestamp": datetime.now().isoformat(),
                }
            )

        except Exception as e:
            logger.error(f"Prediction endpoint failed: {str(e)}")
            return jsonify({"error": f"Prediction failed: {str(e)}"}), 500

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(host=config.API_HOST, port=config.API_PORT, debug=True)
