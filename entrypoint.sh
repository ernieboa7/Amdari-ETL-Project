#!/usr/bin/env bash
set -e

export AIRFLOW_HOME=${AIRFLOW_HOME:-/opt/airflow}

echo "Running Airflow DB migrations..."
airflow db upgrade

echo "Ensuring Airflow admin user exists..."
airflow users create \
  --role Admin \
  --username "${_AIRFLOW_WWW_USER_USERNAME:-airflow}" \
  --password "${_AIRFLOW_WWW_USER_PASSWORD:-airflow}" \
  --firstname Admin \
  --lastname User \
  --email admin@example.com || true

echo "Starting scheduler..."
airflow scheduler &

PORT_ENV=${PORT:-8080}
echo "Starting webserver on port ${PORT_ENV}..."
exec airflow webserver --port "${PORT_ENV}" --hostname 0.0.0.0
