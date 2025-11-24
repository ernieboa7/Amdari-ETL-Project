#!/usr/bin/env bash
set -e

export AIRFLOW_HOME=/opt/airflow

# Make sure Python can import from project root (/opt/airflow)
export PYTHONPATH="${PYTHONPATH}:/opt/airflow"

# Build SQLAlchemy connection string from Neon env vars
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="postgresql+psycopg2://${NEON_DB_USER}:${NEON_DB_PASSWORD}@${NEON_DB_HOST}:${NEON_DB_PORT:-5432}/${NEON_DB_NAME}?sslmode=${NEON_DB_SSLMODE:-require}"

# Keep Airflow as light as possible (good for free tier)
export AIRFLOW__CORE__EXECUTOR=SequentialExecutor
export AIRFLOW__CORE__PARALLELISM="${AIRFLOW__CORE__PARALLELISM:-2}"
export AIRFLOW__CORE__DAG_CONCURRENCY="${AIRFLOW__CORE__DAG_CONCURRENCY:-2}"
export AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG="${AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG:-1}"
export AIRFLOW__WEBSERVER__WORKERS="${AIRFLOW__WEBSERVER__WORKERS:-1}"
export AIRFLOW__CORE__LOAD_EXAMPLES="${AIRFLOW__CORE__LOAD_EXAMPLES:-False}"

echo "Running Airflow DB migrations..."
airflow db upgrade

ADMIN_USER="${_AIRFLOW_WWW_USER_USERNAME:-airflow}"
ADMIN_PASS="${_AIRFLOW_WWW_USER_PASSWORD:-airflow}"

echo "Ensuring default admin user (${ADMIN_USER}) exists..."
airflow users create \
  --username "${ADMIN_USER}" \
  --password "${ADMIN_PASS}" \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com || true

echo "Resetting password for admin user (${ADMIN_USER})..."
airflow users reset-password \
  --username "${ADMIN_USER}" \
  --password "${ADMIN_PASS}" || true

# (Optional) start the scheduler in background so DAGs actually run
echo "Starting Airflow scheduler in background..."
airflow scheduler &

# Render injects PORT; use that so Render can detect the port correctly
PORT="${PORT:-10000}"

echo "Starting Airflow webserver in DEBUG mode on port ${PORT}..."
exec airflow webserver \
  --debug \
  --port "${PORT}" \
  --hostname 0.0.0.0 \
  --access-logfile - \
  --error-logfile -
