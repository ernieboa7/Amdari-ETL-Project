#!/usr/bin/env bash
set -euo pipefail

# Build Airflow connection string from Neon env vars
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="postgresql+psycopg2://${NEON_DB_USER}:${NEON_DB_PASSWORD}@${NEON_DB_HOST}:${NEON_DB_PORT}/${NEON_DB_NAME}?sslmode=${NEON_DB_SSLMODE}"

# Create / migrate metadata DB
airflow db migrate

# Create admin user if it doesn't exist (ignore error if it does)
airflow users create \
  --username "${_AIRFLOW_WWW_USER_USERNAME:-airflow}" \
  --password "${_AIRFLOW_WWW_USER_PASSWORD:-airflow}" \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com || true

# Start scheduler in background
airflow scheduler &

# Start webserver in foreground (Render needs this)
exec airflow webserver --port "${PORT:-8080}"
