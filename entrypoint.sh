#!/usr/bin/env bash
set -e

export AIRFLOW_HOME=${AIRFLOW_HOME:-/opt/airflow}

echo "===> Configuring Airflow DB connection..."

# If Neon env vars are present, wire them into Airflow
if [[ -n "$NEON_DB_HOST" ]]; then
  : "${NEON_DB_PORT:=5432}"
  : "${NEON_DB_SSLMODE:=require}"

  export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="${AIRFLOW__DATABASE__SQL_ALCHEMY_CONN:-postgresql+psycopg2://${NEON_DB_USER}:${NEON_DB_PASSWORD}@${NEON_DB_HOST}:${NEON_DB_PORT}/${NEON_DB_NAME}?sslmode=${NEON_DB_SSLMODE}}"
  echo "Using Neon Postgres as Airflow database."
else
  echo "WARNING: NEON_DB_HOST not set. Falling back to Airflow default DB (likely SQLite)."
fi

echo "===> Running Airflow DB migrations..."
airflow db upgrade

echo "===> Ensuring Airflow admin user exists..."
airflow users create \
  --role Admin \
  --username "${_AIRFLOW_WWW_USER_USERNAME:-airflow}" \
  --password "${_AIRFLOW_WWW_USER_PASSWORD:-airflow}" \
  --firstname Admin \
  --lastname User \
  --email admin@example.com || true

echo "===> Starting scheduler..."
airflow scheduler &

PORT_ENV=${PORT:-8080}
echo "===> Starting webserver on port ${PORT_ENV}..."
exec airflow webserver --port "${PORT_ENV}" --hostname 0.0.0.0
