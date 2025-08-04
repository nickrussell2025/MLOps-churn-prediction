import psycopg2
import pytest


@pytest.fixture(scope="session")
def test_table():
    """Create test table"""
    conn = psycopg2.connect(
        host="localhost",
        port="5433",
        database="monitoring",
        user="postgres",
        password="example",
    )
    cur = conn.cursor()

    # Create test table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS test_table (
            id SERIAL PRIMARY KEY,
            data JSONB,
            value FLOAT
        )
    """)

    conn.commit()
    cur.close()
    conn.close()

    yield

    # Cleanup
    conn = psycopg2.connect(
        host="localhost",
        port="5433",
        database="monitoring",
        user="postgres",
        password="example",
    )
    cur = conn.cursor()
    cur.execute("DROP TABLE IF EXISTS test_table")
    conn.commit()
    cur.close()
    conn.close()


def test_database_write(test_table):
    """Test I can write to database"""
    conn = psycopg2.connect(
        host="localhost",
        port="5433",
        database="monitoring",
        user="postgres",
        password="example",
    )
    cur = conn.cursor()

    # Insert test data
    cur.execute(
        """
        INSERT INTO test_table (data, value) VALUES (%s, %s)
    """,
        ('{"test": "data"}', 0.75),
    )

    # Check it worked
    cur.execute("SELECT COUNT(*) FROM test_table")
    count = cur.fetchone()[0]

    conn.commit()
    cur.close()
    conn.close()

    assert count == 1
