CREATE TABLE predictions (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    input_data JSONB,
    prediction FLOAT,
    model_version VARCHAR(50)
);

CREATE TABLE drift_reports (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    drift_detected BOOLEAN,
    drift_score FLOAT,
    feature_name VARCHAR(100),
    drift_type VARCHAR(50),
    report_data JSONB
);
