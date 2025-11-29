# etl/transform.py

import os
import re
from pathlib import Path

import pandas as pd
import requests
from dotenv import load_dotenv  

# Load .env for local dev; in Docker/Railway this will do nothing
PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / ".env")  

# --------------------
# Config / constants
# --------------------
API_LIMIT = 40
api_count = 0

# Read from environment (.env / Docker / Airflow)
RENTCAST_URL = os.getenv("RENTCAST_URL")
RENTCAST_API_KEY = os.getenv("RENTCAST_API_KEY")

# Base paths relative to project root
BASE_DIR = Path(__file__).resolve().parents[1]

# Kept for backwards compatibility, even if not used anymore
RAW_CSV_DEFAULT = BASE_DIR / "data" / "properties.csv"
CLEAN_CSV_DEFAULT = BASE_DIR / "data" / "clean_properties.csv"


# --------------------------------------------------
# API extract helpers
# --------------------------------------------------
def _get_random_properties(limit: int = 5):
    """
    Call the RentCast random properties endpoint once.
    Respects the global API_LIMIT.
    Returns: list[dict] or None.
    """
    global api_count

    if api_count >= API_LIMIT:
        print(f"API request limit reached ({API_LIMIT}). No more requests will be made.")
        return None

    if not RENTCAST_API_KEY:
        raise RuntimeError(
            "Missing RENTCAST_API_KEY environment variable. "
            "Set it in your .env / Docker / Airflow config."
        )

    headers = {
        "accept": "application/json",
        "X-Api-Key": RENTCAST_API_KEY,
    }

    params = {"limit": limit}

    response = requests.get(RENTCAST_URL, headers=headers, params=params, timeout=10)
    api_count += 1
    print(f"API Request {api_count}/{API_LIMIT}")

    response.raise_for_status()
    return response.json()  # expect list of property dicts


def _fetch_from_api(max_rows: int = 20) -> pd.DataFrame:
    """
    Fetch up to `max_rows` properties from the API
    and return them as a DataFrame (no raw CSV).
    Ensures: <=20 rows and <=20 columns.
    """
    rows: list[dict] = []

    while len(rows) < max_rows:
        remaining = max_rows - len(rows)
        batch_limit = min(5, remaining)  # RentCast per-request limit
        data = _get_random_properties(limit=batch_limit)

        if not data:
            break  # API limit reached or no data

        rows.extend(data)

    if not rows:
        raise RuntimeError("No data fetched from API; cannot transform.")

    df = pd.DataFrame(rows)

    # Hard cap columns (safety)
    if df.shape[1] > 20:
        df = df.iloc[:, :20]

    # Hard cap rows
    df = df.head(max_rows)

    print(f"Fetched {len(df)} rows from API with {df.shape[1]} columns.")
    return df


# --------------------------------------------------
# Transform (NO Postgres load here)
# --------------------------------------------------
def transform_properties(
    raw_csv_path: str | os.PathLike | None = None,   # kept for Airflow compatibility, unused
    clean_csv_path: str | os.PathLike = CLEAN_CSV_DEFAULT,
    save_clean_csv: bool = True,
) -> int:
    """
    Fetch raw data from API, clean and transform it,
    and optionally save the cleaned result to clean_csv_path.

    - Does NOT load to Postgres (that's handled in load.py).
    - Returns:
        int: number of rows in the cleaned dataset.
    """

    clean_csv_path = Path(clean_csv_path)

    # 1) EXTRACT directly from API (ignores raw_csv_path)
    raw_df = _fetch_from_api(max_rows=30)

    # 2) Map API JSON keys -> original CSV schema
    mapping: dict[str, str] = {
        "addressLine1": "Address",
        "city": "City",
        "state": "State",
        "zipCode": "Zip Code",
    }

    # Price comes from lastSalePrice for this endpoint
    if "lastSalePrice" in raw_df.columns:
        mapping["lastSalePrice"] = "Price"

    # Sqft comes from squareFootage if present
    if "squareFootage" in raw_df.columns:
        mapping["squareFootage"] = "Sqft"

    # Use lastSaleDate as our listing date
    if "lastSaleDate" in raw_df.columns:
        mapping["lastSaleDate"] = "Date Listed"

    df = raw_df.rename(columns=mapping)

    # Ensure these columns always exist so downstream code works
    if "Price" not in df.columns:
        df["Price"] = pd.NA
    if "Sqft" not in df.columns:
        df["Sqft"] = pd.NA
    if "Date Listed" not in df.columns:
        df["Date Listed"] = pd.NaT

    required_cols = ["Address", "City", "State", "Zip Code", "Price", "Sqft", "Date Listed"]
    df = df[required_cols]

    print("First few rows (raw from API, mapped):")
    print(df.head(10))

    print("\nFixing column misalignment due to date in Sqft / missing Zip Code (if any)...")

    # Detect rows where Sqft holds a date-like value (YYYY-MM-DD)
    date_pattern = re.compile(r"^\d{4}-\d{2}-\d{2}$")
    bad_mask = df["Sqft"].astype(str).str.fullmatch(date_pattern)

    print(f"Found {bad_mask.sum()} misaligned rows")
    if bad_mask.any():
        bad = df[bad_mask].copy()
        df.loc[bad_mask, "Zip Code"] = pd.NA
        df.loc[bad_mask, "Price"] = bad["Sqft"]
        df.loc[bad_mask, "Sqft"] = bad["Price"]
        df.loc[bad_mask, "Date Listed"] = bad["Date Listed"]

    # Drop rows with missing Address (critical field)
    df = df.dropna(subset=["Address"])
    print(f"After dropping rows with missing Address: {len(df)} rows")

    # Clean Zip Code
    df["Zip Code"] = df["Zip Code"].fillna(0).astype(int).astype(str).str.zfill(5)

    # Rename columns to snake_case
    df.columns = [
        "address",
        "city",
        "state",
        "zip_code",
        "price",
        "sqft",
        "date_listed",
    ]

    # Convert numeric columns safely
    df["price"] = pd.to_numeric(df["price"], errors="coerce")
    df["sqft"] = pd.to_numeric(df["sqft"], errors="coerce")

    print(f"Before dropping NA price/sqft: {len(df)} rows")
    df = df.dropna(subset=["price", "sqft"])    
    print(f"After dropping NA price/sqft: {len(df)} rows")

    df["price"] = df["price"].astype(int)
    df["sqft"] = df["sqft"].astype(int)

    # Reset index so listing_id lines up with rows
    df = df.reset_index(drop=True)

    # Dates and derived columns
    df["date_listed"] = pd.to_datetime(df["date_listed"], errors="coerce")
    df["price_per_sqft"] = (df["price"] / df["sqft"]).round(2)

    # Add listing_id (now guaranteed for every row)
    df["listing_id"] = (
        "MP" + (df.index + 1).astype(str).str.zfill(6)
    )


    # Reorder columns
    df = df[
        [
            "listing_id",
            "address",
            "city",
            "state",
            "zip_code",
            "price",
            "sqft",
            "price_per_sqft",
            "date_listed",
        ]
    ]

    print("\nCLEAN & TRANSFORMED DATA (max 20 rows):")
    print(df.to_string(index=False))

    # Optional: save cleaned CSV for load.py
    if save_clean_csv:
        clean_csv_path.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(clean_csv_path, index=False)
        print(f"\nClean data saved to {clean_csv_path}")
        print("Ready for PostgreSQL load by load.py!")

    return len(df)
