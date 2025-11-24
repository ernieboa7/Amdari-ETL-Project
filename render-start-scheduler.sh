#!/usr/bin/env bash
set -euo pipefail

export AIRFLOW_HOME=/opt/airflow

# Same DB connection as web service
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="postgresql+psycopg2://${NEON_DB_USER}:${NEON_DB_PASSWORD}@${NEON_DB_HOST}:${NEON_DB_PORT:-5432}/${NEON_DB_NAME}?sslmode=${NEON_DB_SSLMODE:-require}"

# Same light settings
export AIRFLOW__CORE__EXECUTOR=SequentialExecutor
export AIRFLOW__CORE__PARALLELISM="${AIRFLOW__CORE__PARALLELISM:-2}"
export AIRFLOW__CORE__DAG_CONCURRENCY="${AIRFLOW__CORE__DAG_CONCURRENCY:-2}"
export AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG="${AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG:-1}"

echo "Running Airflow DB migrations (scheduler)..."
airflow db migrate

echo "Starting Airflow scheduler..."
exec airflow scheduler
