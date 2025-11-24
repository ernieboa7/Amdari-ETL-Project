#!/usr/bin/env bash
set -euo pipefail

export AIRFLOW_HOME=/opt/airflow

# Build SQL Alchemy connection from Neon pieces (env vars set in Render)
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="postgresql+psycopg2://${NEON_DB_USER}:${NEON_DB_PASSWORD}@${NEON_DB_HOST}:${NEON_DB_PORT:-5432}/${NEON_DB_NAME}?sslmode=${NEON_DB_SSLMODE:-require}"

# Make things as light as possible
export AIRFLOW__CORE__EXECUTOR=SequentialExecutor
export AIRFLOW__CORE__PARALLELISM="${AIRFLOW__CORE__PARALLELISM:-2}"
export AIRFLOW__CORE__DAG_CONCURRENCY="${AIRFLOW__CORE__DAG_CONCURRENCY:-2}"
export AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG="${AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG:-1}"
export AIRFLOW__WEBSERVER__WORKERS="${AIRFLOW__WEBSERVER__WORKERS:-1}"

# Apply DB migrations (safe to run every start)
airflow db migrate

# Create admin user if not already present (ignore error if exists)
airflow users create \
  --username "${_AIRFLOW_WWW_USER_USERNAME:-airflow}" \
  --password "${_AIRFLOW_WWW_USER_PASSWORD:-airflow}" \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com || true

# Start scheduler in background (light, SequentialExecutor)
airflow scheduler &

# Start webserver in foreground so Render can track the service
exec airflow webserver --port "${PORT:-8080}"
