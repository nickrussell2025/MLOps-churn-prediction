import os
import sys
from unittest.mock import MagicMock, patch

import numpy as np
import pandas as pd
import pytest
from prefect.testing.utilities import prefect_test_harness
from sklearn.preprocessing import FunctionTransformer

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.mlops_churn.churn_pipeline import (
    load_and_prepare_data,
    prepare_training_data,
    train_all_models,
    train_model_generic,
)


@pytest.fixture(autouse=True, scope="session")
def prefect_test_fixture():
    with prefect_test_harness():
        yield


@pytest.fixture(scope="module")
def sample_data():
    """Generate realistic test data for churn prediction tests"""
    np.random.seed(42)
    n_samples = 20

    data = pd.DataFrame(
        {
            "CreditScore": np.random.randint(500, 850, n_samples),
            "Geography": np.random.choice(["France", "Germany", "Spain"], n_samples),
            "Gender": np.random.choice(["Male", "Female"], n_samples),
            "Age": np.random.randint(18, 70, n_samples),
            "Tenure": np.random.randint(0, 11, n_samples),
            "Balance": np.random.choice(
                [0] + list(range(10000, 200000, 25000)), n_samples
            ),
            "NumOfProducts": np.random.randint(1, 5, n_samples),
            "HasCrCard": np.random.choice([0, 1], n_samples),
            "IsActiveMember": np.random.choice([0, 1], n_samples),
            "EstimatedSalary": np.random.randint(30000, 120000, n_samples),
            "Exited": np.random.choice([0, 1], n_samples, p=[0.8, 0.2]),
        }
    )

    # Ensure specific edge cases for testing
    data.loc[0, "Balance"] = 0
    data.loc[1, "Geography"] = "Germany"
    data.loc[2, "Age"] = 55
    data.loc[3, "NumOfProducts"] = 1
    data.loc[4, "IsActiveMember"] = 0
    data.loc[:4, "Exited"] = 1
    data.loc[5:, "Exited"] = 0

    return data


def test_load_and_prepare_data(sample_data):
    """Test data loading, feature engineering, and data types"""
    X, y = load_and_prepare_data(sample_data)

    # Basic validation
    assert len(X) == len(y) == 20
    assert "Geography" not in X.columns

    # Feature engineering validation
    expected_features = {
        "CreditScore",
        "Gender",
        "Age",
        "Tenure",
        "Balance",
        "NumOfProducts",
        "HasCrCard",
        "IsActiveMember",
        "EstimatedSalary",
        "BalanceActivityInteraction",
        "ZeroBalance",
        "UnderUtilized",
        "AgeRisk",
        "GermanyRisk",
        "GermanyMatureCombo",
    }
    assert expected_features.issubset(set(X.columns))

    # Data type validation
    assert y.dtype == "float64"
    assert X["Gender"].dtype == "category"
    numeric_features = [
        "CreditScore",
        "Age",
        "Tenure",
        "Balance",
        "NumOfProducts",
        "EstimatedSalary",
        "BalanceActivityInteraction",
    ]
    for feature in numeric_features:
        assert X[feature].dtype == "float64"

    # Feature logic validation
    zero_balance_customers = X[X["Balance"] == 0]
    assert all(zero_balance_customers["ZeroBalance"] == 1)
    under_utilized = X[X["NumOfProducts"] == 1]
    assert all(under_utilized["UnderUtilized"] == 1)


def test_prepare_training_data(sample_data):
    """Test train/test split and preprocessor creation"""
    X, y = load_and_prepare_data(sample_data)
    X_train, X_test, y_train, y_test, preprocessor, class_ratio = prepare_training_data(
        X, y
    )

    # Data split validation
    assert all(len(dataset) > 0 for dataset in [X_train, X_test, y_train, y_test])
    assert len(X_train) + len(X_test) == len(X)
    assert len(y_train) + len(y_test) == len(y)
    assert class_ratio > 0

    # Preprocessor validation
    transformer_names = [name for name, _, _ in preprocessor.transformers]
    assert {"num", "bin", "cat"}.issubset(set(transformer_names))


@pytest.fixture
def model_sample_data():
    """Create minimal sample data for model testing"""
    np.random.seed(123)

    X_train = pd.DataFrame(
        {"feature1": np.random.rand(10), "feature2": np.random.rand(10)}
    )
    y_train = np.array([0, 1, 0, 1, 0, 1, 0, 1, 0, 1])
    X_test = pd.DataFrame(
        {"feature1": np.random.rand(5), "feature2": np.random.rand(5)}
    )
    y_test = np.array([0, 1, 0, 1, 0])
    preprocessor = FunctionTransformer(validate=True)

    return X_train, y_train, X_test, y_test, preprocessor


@patch("src.mlops_churn.churn_pipeline.mlflow.start_run")
@patch("src.mlops_churn.churn_pipeline.GridSearchCV")
@patch("src.mlops_churn.churn_pipeline.mlflow.active_run")
@patch("src.mlops_churn.churn_pipeline.mlflow.sklearn.log_model")
@patch("src.mlops_churn.churn_pipeline.mlflow.log_params")
@patch("src.mlops_churn.churn_pipeline.mlflow.log_metrics")
def test_train_model_generic(
    mock_log_metrics,
    mock_log_params,
    mock_log_model,
    mock_active_run,
    mock_gs,
    mock_mlflow,
    model_sample_data,
):
    """Test generic model training function"""
    X_train, y_train, X_test, y_test, preprocessor = model_sample_data

    # Setup mocks
    mock_gs_instance = MagicMock()
    mock_gs_instance.best_estimator_.predict.return_value = y_test
    mock_gs_instance.best_score_ = 0.85
    mock_gs_instance.best_params_ = {"param": 1}
    mock_gs.return_value = mock_gs_instance

    mock_run = MagicMock()
    mock_run.info.run_id = "test_run_id"
    mock_active_run.return_value = mock_run
    mock_mlflow.return_value.__enter__.return_value = mock_run

    # Execute and validate
    results = train_model_generic(
        "TestModel",
        estimator=MagicMock(),
        params={"param": [1, 2]},
        preprocessor=preprocessor,
        X_train=X_train,
        y_train=y_train,
        X_test=X_test,
        y_test=y_test,
    )

    assert "model" in results
    assert results["cv_score"] == 0.85
    assert "test_recall" in results
    assert "run_id" in results
    assert 0 <= results["test_recall"] <= 1


@patch("src.mlops_churn.churn_pipeline.train_model_generic")
def test_train_all_models(mock_train_generic, model_sample_data):
    """Test training multiple models"""
    X_train, y_train, X_test, y_test, preprocessor = model_sample_data

    mock_train_generic.return_value = {
        "model": MagicMock(),
        "cv_score": 0.8,
        "test_recall": 0.7,
        "test_f1": 0.75,
        "test_precision": 0.7,
        "run_id": "1234",
    }

    results = train_all_models(preprocessor, 1.5, X_train, y_train, X_test, y_test)

    assert isinstance(results, dict)
    expected_models = {"LogisticRegression"}
    assert set(results.keys()) == expected_models

    for _name, res in results.items():
        assert all(
            key in res
            for key in [
                "cv_score",
                "test_recall",
                "test_f1",
                "test_precision",
                "model",
                "run_id",
            ]
        )
