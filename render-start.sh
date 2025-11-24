#!/usr/bin/env bash
set -euo pipefail

export AIRFLOW_HOME=/opt/airflow

# Build SQLAlchemy connection string from Neon env vars
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="postgresql+psycopg2://${NEON_DB_USER}:${NEON_DB_PASSWORD}@${NEON_DB_HOST}:${NEON_DB_PORT:-5432}/${NEON_DB_NAME}?sslmode=${NEON_DB_SSLMODE:-require}"

# Keep Airflow as light as possible
export AIRFLOW__CORE__EXECUTOR=SequentialExecutor
export AIRFLOW__CORE__PARALLELISM="${AIRFLOW__CORE__PARALLELISM:-2}"
export AIRFLOW__CORE__DAG_CONCURRENCY="${AIRFLOW__CORE__DAG_CONCURRENCY:-2}"
export AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG="${AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG:-1}"
export AIRFLOW__WEBSERVER__WORKERS="${AIRFLOW__WEBSERVER__WORKERS:-1}"

echo "Running Airflow DB migrations..."
airflow db migrate

echo "Creating default admin user (if needed)..."
airflow users create \
  --username "${_AIRFLOW_WWW_USER_USERNAME:-airflow}" \
  --password "${_AIRFLOW_WWW_USER_PASSWORD:-airflow}" \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com || true

# Render injects PORT; default to 10000 if not present
PORT="${PORT:-10000}"
echo "Starting Airflow webserver on port ${PORT}..."
exec airflow webserver --port "${PORT}"
