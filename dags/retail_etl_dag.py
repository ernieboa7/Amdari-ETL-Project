# dags/retail_properties_etl.py

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator

from etl.transform import transform_properties, CLEAN_CSV_DEFAULT
from etl.load import load_to_neon, verify_load, get_db_config_from_env

# ------------- CONSTANT PATHS -----------------

CLEAN_CSV = CLEAN_CSV_DEFAULT    # e.g. Path("data/clean_properties.csv")


# ------------- WRAPPER FUNCTIONS FOR AIRFLOW -----------------

def extract_raw_properties(**context):
    
    #Extract step placeholder for API-based pipeline.
    
    import os

    api_key = os.getenv("RENTCAST_API_KEY")
    if not api_key:
        raise RuntimeError(
            "RENTCAST_API_KEY is not set. "
            "Please configure it in your environment (.env / Railway / Airflow)."
        )

    print("Extract step OK - API key found; data will be fetched in transform step.")


def transform_task_callable(**context):
    """
    Airflow-compatible wrapper to call transform_properties().
    Fetches from API, transforms in memory, and writes clean CSV.
    """
    rows = transform_properties(clean_csv_path=CLEAN_CSV, save_clean_csv=True)
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

with DAG(
    dag_id="ETL",
    default_args=default_args,
    description="Retail Analytics: ETL pipeline for properties API into Neon Postgres",
    schedule_interval=None,          # <--None for manual only; change to '@daily' if you want a schedule
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["Retail", "ETL", "Neon", "Properties"],
) as dag:

    extract_task = PythonOperator(
        task_id="Extract_Raw_Data",
        python_callable=extract_raw_properties,
    )

    transform_task = PythonOperator(
        task_id="Transform_Data",
        python_callable=transform_task_callable,
    )

    load_task = PythonOperator(
        task_id="Load_To_Database",
        python_callable=load_task_callable,
    )

    verify_task = PythonOperator(
        task_id="Verify_Load_Success",
        python_callable=verify_task_callable,
    )

    # ETL order: extract → transform → load → verify
    extract_task >> transform_task >> load_task >> verify_task
