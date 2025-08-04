import atexit
import json
import logging
import os
import threading

import psycopg2.pool

logger = logging.getLogger(__name__)

# Global connection pool
_connection_pool = None
_pool_lock = threading.Lock()


def get_connection_pool():
    global _connection_pool
    if _connection_pool is None:
        with _pool_lock:
            if _connection_pool is None:
                _connection_pool = psycopg2.pool.ThreadedConnectionPool(
                    minconn=1,
                    maxconn=5,
                    host=os.getenv("DATABASE_HOST"),
                    port=os.getenv("DATABASE_PORT", "5432"),
                    database=os.getenv("DATABASE_NAME", "monitoring"),
                    user=os.getenv("DATABASE_USER", "postgres"),
                    password=os.getenv("DATABASE_PASSWORD"),
                    connect_timeout=10,
                )
                atexit.register(
                    lambda: _connection_pool.closeall() if _connection_pool else None
                )

    return _connection_pool


def get_db_connection():
    try:
        pool = get_connection_pool()
        return pool.getconn()
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        return None


def return_connection(conn):
    if conn:
        pool = get_connection_pool()
        pool.putconn(conn)


def initialize_database():
    conn = get_db_connection()
    if not conn:
        return False

    try:
        conn.autocommit = True
        cur = conn.cursor()

        cur.execute("""
            CREATE TABLE IF NOT EXISTS predictions (
                id SERIAL PRIMARY KEY,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                input_data JSONB,
                prediction FLOAT,
                model_version VARCHAR(50)
            )
        """)

        cur.execute("""
            CREATE TABLE IF NOT EXISTS drift_reports (
                id SERIAL PRIMARY KEY,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                drift_detected BOOLEAN,
                drift_score FLOAT,
                feature_name VARCHAR(100),
                drift_type VARCHAR(50),
                report_data JSONB
            )
        """)

        logger.info("Database tables initialized successfully")
        return True
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        return False
    finally:
        if "cur" in locals():
            cur.close()
        return_connection(conn)


def log_prediction(input_data, prediction, model_version):
    conn = get_db_connection()
    if not conn:
        return False
    try:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO predictions (timestamp, input_data, prediction, model_version) VALUES (NOW(), %s, %s, %s)",
            (json.dumps(input_data), prediction, model_version),
        )
        conn.commit()
        return True
    except Exception as e:
        logger.error(f"Error logging prediction: {e}")
        return False
    finally:
        if "cur" in locals():
            cur.close()
        return_connection(conn)


def log_drift_result(
    drift_detected, drift_score, feature_name, drift_type, report_data
):
    """Log drift detection result to database"""
    conn = get_db_connection()
    if not conn:
        return False

    try:
        cur = conn.cursor()
        cur.execute(
            """INSERT INTO drift_reports
               (timestamp, drift_detected, drift_score, feature_name, drift_type, report_data)
               VALUES (NOW(), %s, %s, %s, %s, %s)""",
            (
                drift_detected,
                drift_score,
                feature_name,
                drift_type,
                json.dumps(report_data),
            ),
        )
        conn.commit()
        logger.info(f"Drift result logged: {drift_detected}, score: {drift_score}")
        return True
    except Exception as e:
        logger.error(f"Error logging drift result: {e}")
        return False
    finally:
        if "cur" in locals():
            cur.close()
        return_connection(conn)
