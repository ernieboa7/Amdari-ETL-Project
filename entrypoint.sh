#!/usr/bin/env bash
set -e

# Default Airflow home if not set
export AIRFLOW_HOME=${AIRFLOW_HOME:-/opt/airflow}

echo "===> Applying lightweight Airflow defaults for small containers..."

# These defaults keep the process count and memory footprint low.
# Railway env vars can override any of them if you need more power later.
export AIRFLOW__CORE__EXECUTOR="${AIRFLOW__CORE__EXECUTOR:-SequentialExecutor}"
export AIRFLOW__CORE__PARALLELISM="${AIRFLOW__CORE__PARALLELISM:-1}"
export AIRFLOW__CORE__DAG_CONCURRENCY="${AIRFLOW__CORE__DAG_CONCURRENCY:-1}"
export AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG="${AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG:-1}"
export AIRFLOW__SCHEDULER__MAX_THREADS="${AIRFLOW__SCHEDULER__MAX_THREADS:-1}"
export AIRFLOW__WEBSERVER__WORKERS="${AIRFLOW__WEBSERVER__WORKERS:-1}"
export AIRFLOW__WEBSERVER__WEB_SERVER_WORKER_TIMEOUT="${AIRFLOW__WEBSERVER__WEB_SERVER_WORKER_TIMEOUT:-120}"

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

# Start scheduler in background (needed even with SequentialExecutor)
echo "===> Scheduler temporarily disabled for debugging..."
#echo "===> Starting scheduler (background)..."
#airflow scheduler &

# Start webserver in foreground so container stays alive
PORT_ENV=${PORT:-8080}
echo "===> Starting webserver on port ${PORT_ENV}..."
exec airflow webserver --port "${PORT_ENV}" --hostname 0.0.0.0
