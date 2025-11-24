import os
from pathlib import Path

import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv

# --------------------------------------------------------------------
# ENV + PATH SETUP
# --------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parents[1]

# Load .env from project root (works locally; on Render env comes from dashboard)
load_dotenv(PROJECT_ROOT / ".env")

CLEAN_CSV_DEFAULT = PROJECT_ROOT / "data" / "clean_properties.csv"


# --------------------------------------------------------------------
# DB CONFIG
# --------------------------------------------------------------------

def get_db_config_from_env() -> dict:
    """
    Read Neon DB config from environment variables.
    Raises if required variables are missing.
    """
    required_vars = [
        "NEON_DB_HOST",
        "NEON_DB_NAME",
        "NEON_DB_USER",
        "NEON_DB_PASSWORD",
    ]

    missing = [var for var in required_vars if not os.getenv(var)]
    if missing:
        raise RuntimeError(f"Missing required env vars: {missing}")

    return {
        "host": os.getenv("NEON_DB_HOST"),
        "dbname": os.getenv("NEON_DB_NAME"),
        "port": os.getenv("NEON_DB_PORT", "5432"),
        "user": os.getenv("NEON_DB_USER"),
        "password": os.getenv("NEON_DB_PASSWORD"),
        "sslmode": os.getenv("NEON_DB_SSLMODE", "require"),
    }


# --------------------------------------------------------------------
# LOAD STEP
# --------------------------------------------------------------------

def load_to_neon(
    clean_csv_path: str | os.PathLike = CLEAN_CSV_DEFAULT,
    db_config: dict | None = None,
) -> int:
    """
    Load the cleaned CSV into the Neon Postgres 'properties' table using upsert.

    Returns:
        int: Number of rows attempted to load.
    """
    clean_csv_path = Path(clean_csv_path)

    if not clean_csv_path.exists():
        raise FileNotFoundError(f"Clean CSV not found at {clean_csv_path}")

    if db_config is None:
        db_config = get_db_config_from_env()

    # Read clean CSV
    df = pd.read_csv(clean_csv_path, parse_dates=["date_listed"])

    # Ensure we only load rows with a valid listing_id
    before = len(df)
    df = df[df["listing_id"].notna()].copy()
    if len(df) < before:
        print(
            f"Skipping {before - len(df)} row(s) with missing listing_id "
            f"before load."
        )

    # Make sure listing_id is string (matches VARCHAR PK)
    df["listing_id"] = df["listing_id"].astype(str)

    print("Connecting to PostgreSQL (Neon)...")
    try:
        conn = psycopg2.connect(**db_config)
        cur = conn.cursor()
        print("Connected!")
    except Exception as e:
        raise RuntimeError(f"Connection failed: {e}")

    # Create table if not exists
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS properties (
            listing_id VARCHAR(10) PRIMARY KEY,
            address   TEXT NOT NULL,
            city      TEXT NOT NULL,
            state     CHAR(2) NOT NULL,
            zip_code  CHAR(5) NOT NULL,
            price     INTEGER NOT NULL,
            sqft      INTEGER NOT NULL,
            price_per_sqft NUMERIC(10,2),
            date_listed DATE
        );
        """
    )
    conn.commit()
    print("Table 'properties' is ready.")

    # Convert rows into tuples for execute_batch
    records = [
        (
            r["listing_id"],
            r["address"],
            r["city"],
            r["state"],
            r["zip_code"],
            int(r["price"]),
            int(r["sqft"]),
            float(r["price_per_sqft"]) if pd.notna(r["price_per_sqft"]) else None,
            r["date_listed"] if not pd.isna(r["date_listed"]) else None,
        )
        for _, r in df.iterrows()
    ]

    upsert_sql = """
        INSERT INTO properties (
            listing_id, address, city, state, zip_code,
            price, sqft, price_per_sqft, date_listed
        ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (listing_id) DO UPDATE SET
            price           = EXCLUDED.price,
            sqft            = EXCLUDED.sqft,
            price_per_sqft  = EXCLUDED.price_per_sqft,
            date_listed     = EXCLUDED.date_listed;
    """

    print(f"Loading {len(records)} records...")
    execute_batch(cur, upsert_sql, records)
    conn.commit()

    # Optional: total count in table for info
    cur.execute("SELECT COUNT(*) FROM properties;")
    total = cur.fetchone()[0]
    print(f"Database now has {total} rows in 'properties'.")

    cur.close()
    conn.close()

    print("LOAD COMPLETE! Data loaded into Neon.")

    return len(records)


# --------------------------------------------------------------------
# VERIFY STEP
# --------------------------------------------------------------------

def verify_load(
    clean_csv_path: str | os.PathLike = CLEAN_CSV_DEFAULT,
    db_config: dict | None = None,
) -> None:
    """
    Verification step to ensure loading was successful.

    Compares:
    - number of rows in the clean CSV *that have a listing_id*
    - number of rows currently in the 'properties' table *for those listing_ids*

    Raises:
        ValueError if the database count for this batch's listing_ids
        is less than the CSV count for listing_ids.
    """
    clean_csv_path = Path(clean_csv_path)

    if not clean_csv_path.exists():
        raise FileNotFoundError(f"Clean CSV not found at {clean_csv_path}")

    if db_config is None:
        db_config = get_db_config_from_env()

    df = pd.read_csv(clean_csv_path)

    # Only consider rows with a listing_id (same as load_to_neon)
    df = df[df["listing_id"].notna()].copy()
    df["listing_id"] = df["listing_id"].astype(str)

    expected_rows = len(df)
    print(f"Clean CSV has {expected_rows} row(s) with a listing_id.")

    if expected_rows == 0:
        raise ValueError("No rows with listing_id found in clean CSV; nothing to verify.")

    listing_ids = list(df["listing_id"])

    print("Connecting to PostgreSQL (Neon) for verification...")
    conn = psycopg2.connect(**db_config)
    cur = conn.cursor()

    # Count how many of these listing_ids are present in the DB
    cur.execute(
        """
        SELECT COUNT(*) 
        FROM properties
        WHERE listing_id = ANY(%s);
        """,
        (listing_ids,),
    )
    db_rows = cur.fetchone()[0]

    cur.close()
    conn.close()

    print(
        f"Database currently has {db_rows} rows in 'properties' "
        f"matching this batch's listing_ids."
    )

    if db_rows < expected_rows:
        raise ValueError(
            f"Load verification FAILED: DB rows for this batch ({db_rows}) "
            f"< expected rows with listing_id ({expected_rows})"
        )

    print(
        "Load verification PASSED: All rows with listing_id from the clean CSV "
        "are present in the database."
    )
