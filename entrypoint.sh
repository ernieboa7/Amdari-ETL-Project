#!/usr/bin/env bash
set -e

# Default Airflow home if not set
export AIRFLOW_HOME=${AIRFLOW_HOME:-/opt/airflow}

echo "===> Applying lightweight Airflow defaults for small containers..."

# Keep resource usage low – Railway env vars can override these if needed
export AIRFLOW__CORE__EXECUTOR="${AIRFLOW__CORE__EXECUTOR:-SequentialExecutor}"
export AIRFLOW__CORE__PARALLELISM="${AIRFLOW__CORE__PARALLELISM:-1}"
export AIRFLOW__CORE__DAG_CONCURRENCY="${AIRFLOW__CORE__DAG_CONCURRENCY:-1}"
export AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG="${AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG:-1}"
export AIRFLOW__SCHEDULER__MAX_THREADS="${AIRFLOW__SCHEDULER__MAX_THREADS:-1}"
export AIRFLOW__WEBSERVER__WORKERS="${AIRFLOW__WEBSERVER__WORKERS:-1}"
export AIRFLOW__WEBSERVER__WEB_SERVER_WORKER_TIMEOUT="${AIRFLOW__WEBSERVER__WEB_SERVER_WORKER_TIMEOUT:-120}"

# Role: webserver (default) or scheduler – set via env AIRFLOW_ROLE
AIRFLOW_ROLE="${AIRFLOW_ROLE:-webserver}"
echo "===> Starting Airflow role: ${AIRFLOW_ROLE}"

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

# Create admin user (idempotent; safe to run from both services)
echo "===> Ensuring Airflow admin user exists..."
airflow users create \
  --role Admin \
  --username "${_AIRFLOW_WWW_USER_USERNAME:-airflow}" \
  --password "${_AIRFLOW_WWW_USER_PASSWORD:-airflow}" \
  --firstname Admin \
  --lastname User \
  --email admin@example.com || true

case "$AIRFLOW_ROLE" in
  webserver)
    echo "===> Starting webserver..."
    PORT_ENV=${PORT:-8080}
    exec airflow webserver --port "${PORT_ENV}" --hostname 0.0.0.0
    ;;

  scheduler)
    echo "===> Starting tiny HTTP health server on port 8080 for Railway..."
    # This built-in HTTP server will respond 200 OK for /health (and any path),
    # satisfying Railway's healthcheck while the scheduler runs.
    python -m http.server 8080 --bind 0.0.0.0 >/dev/null 2>&1 &

    echo "===> Starting scheduler..."
    exec airflow scheduler
    ;;

  *)
    echo "ERROR: Unknown AIRFLOW_ROLE '${AIRFLOW_ROLE}'. Expected 'webserver' or 'scheduler'."
    exit 1
    ;;
esac
