from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.python import PythonOperator

from etl.transform import transform_properties, RAW_CSV_DEFAULT, CLEAN_CSV_DEFAULT
from etl.load import load_to_neon, verify_load, get_db_config_from_env

# ------------- CONSTANT PATHS -----------------

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_CSV = RAW_CSV_DEFAULT        # data/properties.csv
CLEAN_CSV = CLEAN_CSV_DEFAULT    # data/clean_properties.csv


# ------------- WRAPPER FUNCTIONS FOR AIRFLOW -----------------

def extract_raw_properties(**context):
    """
    Simple extract step: ensure the raw CSV exists.
    This could later be extended to download from S3 or another source.
    """
    if not RAW_CSV.exists():
        raise FileNotFoundError(f"Raw CSV not found at {RAW_CSV}")
    print(f"Extract step OK - file present: {RAW_CSV}")


def transform_task_callable(**context):
    """
    Airflow-compatible wrapper to call transform_properties().
    """
    rows = transform_properties(raw_csv_path=RAW_CSV, clean_csv_path=CLEAN_CSV)
    print(f"Transform step completed with {rows} cleaned rows.")


def load_task_callable(**context):
    """
    Airflow-compatible wrapper to call load_to_neon().
    """
    db_config = get_db_config_from_env()
    loaded_rows = load_to_neon(clean_csv_path=CLEAN_CSV, db_config=db_config)
    print(f"Load step completed. Attempted to load {loaded_rows} rows.")


def verify_task_callable(**context):
    """
    Airflow-compatible wrapper to call verify_load().
    Fails the task if verification fails.
    """
    db_config = get_db_config_from_env()
    verify_load(clean_csv_path=CLEAN_CSV, db_config=db_config)


# ------------- DAG DEFINITION -----------------

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

# IMPORTANT: schedule_interval=None → manual trigger only
with DAG(
    dag_id="retail_properties_etl",
    default_args=default_args,
    description="Retail Analytics: ETL pipeline for properties CSV into Neon Postgres",
    schedule_interval=None,          # <-- manual only
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["retail", "etl", "neon", "properties"],
) as dag:

    extract_task = PythonOperator(
        task_id="extract_raw_properties",
        python_callable=extract_raw_properties,
    )

    transform_task = PythonOperator(
        task_id="transform_properties",
        python_callable=transform_task_callable,
    )

    load_task = PythonOperator(
        task_id="load_to_neon",
        python_callable=load_task_callable,
    )

    verify_task = PythonOperator(
        task_id="verify_load_success",
        python_callable=verify_task_callable,
    )

    # ETL order: extract → transform → load → verify
    extract_task >> transform_task >> load_task >> verify_task
