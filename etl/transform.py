import os
import re
from pathlib import Path

import pandas as pd

# Base paths relative to project root
BASE_DIR = Path(__file__).resolve().parents[1]
RAW_CSV_DEFAULT = BASE_DIR / "data" / "properties.csv"
CLEAN_CSV_DEFAULT = BASE_DIR / "data" / "clean_properties.csv"


def transform_properties(
    raw_csv_path: str | os.PathLike = RAW_CSV_DEFAULT,
    clean_csv_path: str | os.PathLike = CLEAN_CSV_DEFAULT,
) -> int:
    """
    Read the raw CSV, fix column misalignment, clean and transform the data,
    and save the cleaned result to clean_csv_path.

    Returns:
        int: number of rows in the cleaned dataset.
    """
    raw_csv_path = Path(raw_csv_path)
    clean_csv_path = Path(clean_csv_path)

    if not raw_csv_path.exists():
        raise FileNotFoundError(f"Raw CSV not found at {raw_csv_path}")

    print(f"Reading raw data from {raw_csv_path}...")
    df = pd.read_csv(raw_csv_path)
    print(f"Raw data shape: {df.shape}\n")
    print("First few rows (raw):")
    print(df.head(10))

    print("\nFixing column misalignment due to date in Sqft / missing Zip Code...")

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

    # Dates and derived columns
    df["date_listed"] = pd.to_datetime(df["date_listed"], errors="coerce")
    df["price_per_sqft"] = (df["price"] / df["sqft"]).round(2)

    # Add listing_id
    df = df.assign(
        listing_id="MP" + pd.Series(range(1, len(df) + 1)).astype(str).str.zfill(6)
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

    # Ensure output directory exists
    clean_csv_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(clean_csv_path, index=False)

    print("\nCLEAN & TRANSFORMED DATA")
    #print(df.to_string(index=False))
    print(df.head(10).to_string(index=False))
    print(f"\nClean data saved to {clean_csv_path}")
    print("Ready for PostgreSQL load!")

    return len(df)
