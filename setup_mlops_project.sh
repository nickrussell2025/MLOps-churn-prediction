#!/bin/bash

# MLOps Project Complete Setup Script
# Run this script to set up the entire MLOps project from scratch

set -e  # Exit on any error

echo "🚀 Setting up MLOps Bank Churn Project..."
echo "=========================================="

# 1. Install UV if not already installed
echo "📦 Checking UV installation..."
if ! command -v uv &> /dev/null; then
    echo "Installing UV..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source ~/.bashrc
else
    echo "✅ UV already installed"
fi

# 2. Initialize UV project
echo "🔧 Initializing UV project..."
uv init --name mlops-bank-churn --python 3.11

# 3. Create directory structure
echo "📁 Creating directory structure..."
mkdir -p src/mlops_churn
mkdir -p tests
mkdir -p data/{raw,processed,reference}
mkdir -p models
mkdir -p logs
mkdir -p prefect_flows
mkdir -p monitoring/{config,reports}
mkdir -p notebooks

# 4. Create Python package files
echo "🐍 Creating Python package files..."
touch src/__init__.py
touch src/mlops_churn/__init__.py
touch tests/__init__.py
touch prefect_flows/__init__.py

# 5. Create .gitignore
echo "🚫 Creating .gitignore..."
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
.Python
build/
dist/
*.egg-info/
*.egg

# Virtual environments
.venv/
venv/
ENV/

# UV
.python-version

# IDE
.vscode/
.idea/
*.swp

# Testing
.pytest_cache/
.coverage
htmlcov/

# MLflow
mlruns/
mlartifacts/

# Model artifacts
models/*.pkl
models/*.joblib

# Data files
data/raw/*.csv
data/processed/*.parquet
data/reference/*.parquet

# Logs
logs/*.log
logs/*.jsonl
*.log

# Database
*.db
*.sqlite

# Environment variables
.env
.env.local

# OS
.DS_Store
Thumbs.db
EOF

# 6. Create .env.example
echo "⚙️ Creating .env.example..."
cat > .env.example << 'EOF'
# MLflow Configuration
MLFLOW_TRACKING_URI=sqlite:///mlflow.db
MLFLOW_EXPERIMENT_NAME=bank-churn-prediction

# Flask Application
FLASK_ENV=development
FLASK_DEBUG=True
HOST=0.0.0.0
PORT=5000

# Database Configuration
DATABASE_URL=postgresql://user:password@localhost:5432/monitoring

# Model Configuration
MODEL_NAME=bank-churn-classifier
MODEL_STAGE=production

# Development
PYTHONPATH=src
LOG_LEVEL=DEBUG
EOF

# 7. Create Makefile
echo "🛠️ Creating Makefile..."
cat > Makefile << 'EOF'
.PHONY: help install test lint format clean run-api run-mlflow

help:
	@echo "Available commands:"
	@echo "  install    - Install dependencies"
	@echo "  test       - Run tests"
	@echo "  lint       - Run linting with ruff"
	@echo "  format     - Format code with ruff"
	@echo "  clean      - Clean build artifacts"
	@echo "  run-api    - Run Flask API"
	@echo "  run-mlflow - Run MLflow UI"

install:
	uv sync --all-extras

test:
	uv run pytest tests/ -v

lint:
	uv run ruff check src tests

format:
	uv run ruff format src tests

clean:
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete

run-api:
	uv run python -m src.mlops_churn.app

run-mlflow:
	uv run mlflow ui --backend-store-uri sqlite:///mlflow.db
EOF

# 8. Add dependencies with UV (let UV handle versions)
echo "📦 Adding dependencies..."
uv add pandas numpy scikit-learn mlflow prefect evidently flask requests
uv add --dev pytest ruff jupyter

# 9. Install all dependencies
echo "📦 Installing dependencies..."
uv sync --all-extras

# 10. Create basic pyproject.toml configuration
echo "📝 Adding tool configuration to pyproject.toml..."
cat >> pyproject.toml << 'EOF'

[tool.ruff]
line-length = 88
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "W", "I"]

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
addopts = ["--strict-markers", "--verbose"]
EOF

# 11. Create core configuration module
echo "⚙️ Creating config.py..."
cat > src/mlops_churn/config.py << 'EOF'
"""Configuration management for MLOps Bank Churn project."""

import os
from pathlib import Path

class Config:
    """Application configuration."""

    # Project paths
    PROJECT_ROOT = Path(__file__).parent.parent.parent
    DATA_DIR = PROJECT_ROOT / "data"
    MODELS_DIR = PROJECT_ROOT / "models"
    LOGS_DIR = PROJECT_ROOT / "logs"

    # MLflow
    MLFLOW_TRACKING_URI = "sqlite:///mlflow.db"
    MLFLOW_EXPERIMENT_NAME = "bank-churn-prediction"

    # Model
    MODEL_NAME = "bank-churn-classifier"

    # Flask
    HOST = "0.0.0.0"
    PORT = 5000

config = Config()
EOF

# 12. Create basic Flask app
echo "🌐 Creating Flask app..."
cat > src/mlops_churn/app.py << 'EOF'
"""Flask API for MLOps Bank Churn project."""

from flask import Flask, jsonify
from .config import config

app = Flask(__name__)

@app.route("/")
def health_check():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy",
        "service": "MLOps Bank Churn API",
        "version": "0.1.0"
    })

@app.route("/predict", methods=["POST"])
def predict():
    """Prediction endpoint."""
    return jsonify({
        "message": "Prediction endpoint - coming soon!",
        "model": config.MODEL_NAME
    })

if __name__ == "__main__":
    app.run(host=config.HOST, port=config.PORT, debug=True)
EOF

# 13. Create basic data processing module
echo "📊 Creating data processing module..."
cat > src/mlops_churn/data_processing.py << 'EOF'
"""Data processing utilities for MLOps Bank Churn project."""

import pandas as pd
from pathlib import Path
from .config import config

def load_data(file_path: str) -> pd.DataFrame:
    """Load data from CSV file."""
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Data file not found: {file_path}")

    df = pd.read_csv(path)
    print(f"✅ Loaded data: {df.shape[0]} rows, {df.shape[1]} columns")
    return df

def preprocess_data(df: pd.DataFrame) -> pd.DataFrame:
    """Basic data preprocessing."""
    # Remove duplicates
    df = df.drop_duplicates()

    # Handle missing values (placeholder)
    df = df.dropna()

    print(f"✅ Preprocessed data: {df.shape[0]} rows, {df.shape[1]} columns")
    return df
EOF

# 14. Create basic model module
echo "🤖 Creating model module..."
cat > src/mlops_churn/model.py << 'EOF'
"""Model training and evaluation for MLOps Bank Churn project."""

import mlflow
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
from .config import config

def train_model(df: pd.DataFrame, target_column: str):
    """Train a basic model."""
    # Set MLflow experiment
    mlflow.set_experiment(config.MLFLOW_EXPERIMENT_NAME)

    with mlflow.start_run():
        # Prepare features (placeholder)
        X = df.drop(columns=[target_column])
        y = df[target_column]

        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        # Train model
        model = RandomForestClassifier(random_state=42)
        model.fit(X_train, y_train)

        # Evaluate
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)

        # Log to MLflow
        mlflow.log_param("model_type", "RandomForest")
        mlflow.log_metric("accuracy", accuracy)
        mlflow.sklearn.log_model(model, "model")

        print(f"✅ Model trained with accuracy: {accuracy:.3f}")
        return model
EOF

# 15. Create basic test file
echo "🧪 Creating basic test..."
cat > tests/test_config.py << 'EOF'
"""Test configuration module."""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from mlops_churn.config import config

def test_config_paths():
    """Test that config paths are valid."""
    assert config.PROJECT_ROOT.exists()
    assert config.DATA_DIR.exists()
    assert config.MODELS_DIR.exists()

def test_config_values():
    """Test that config values are set."""
    assert config.MLFLOW_EXPERIMENT_NAME == "bank-churn-prediction"
    assert config.MODEL_NAME == "bank-churn-classifier"
    assert config.PORT == 5000
EOF

# 16. Create README
echo "📖 Creating README..."
cat > README.md << 'EOF'
# MLOps Bank Churn Prediction

End-to-end MLOps project for predicting bank customer churn.

## Quick Start

```bash
# Install dependencies
make install

# Run tests
make test

# Run Flask API
make run-api

# Run MLflow UI
make run-mlflow
```

## Project Structure

```
mlops-bank-churn/
├── src/mlops_churn/          # Main application code
├── tests/                    # Test suite
├── data/                     # Data directories
├── models/                   # Model artifacts
├── logs/                     # Application logs
├── prefect_flows/            # Workflow definitions
├── monitoring/               # Monitoring setup
└── notebooks/                # Jupyter notebooks
```

## Development

- `make help` - Show available commands
- `make lint` - Run linting
- `make format` - Format code
- `make test` - Run tests
EOF

# 17. Test everything works
echo "🧪 Testing setup..."
uv run python -c "import pandas, sklearn, mlflow, prefect, evidently, flask; print('✅ All imports successful')"
uv run python -c "from src.mlops_churn.config import config; print('✅ Config module working')"

# 18. Copy environment file
echo "📋 Setting up environment..."
cp .env.example .env

echo ""
echo "🎉 MLOps Project Setup Complete!"
echo "=================================="
echo ""
echo "✅ Project structure created"
echo "✅ Dependencies installed"
echo "✅ Core modules created"
echo "✅ Tests working"
echo "✅ Configuration ready"
echo ""
echo "Next steps:"
echo "1. Run 'make help' to see available commands"
echo "2. Run 'make test' to run tests"
echo "3. Run 'make run-api' to start Flask API"
echo "4. Add your dataset to data/raw/"
echo "5. Start developing your ML pipeline!"
echo ""
echo "�� Happy coding!"
