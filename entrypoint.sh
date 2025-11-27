#!/usr/bin/env bash
set -e

export AIRFLOW_HOME=${AIRFLOW_HOME:-/opt/airflow}

echo "===> Applying lightweight defaults..."

export AIRFLOW__CORE__EXECUTOR="${AIRFLOW__CORE__EXECUTOR:-SequentialExecutor}"
export AIRFLOW__CORE__PARALLELISM="${AIRFLOW__CORE__PARALLELISM:-1}"
export AIRFLOW__CORE__DAG_CONCURRENCY="${AIRFLOW__CORE__DAG_CONCURRENCY:-1}"
export AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG="${AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG:-1}"
export AIRFLOW__SCHEDULER__MAX_THREADS="${AIRFLOW__SCHEDULER__MAX_THREADS:-1}"
export AIRFLOW__WEBSERVER__WORKERS="${AIRFLOW__WEBSERVER__WORKERS:-1}"
export AIRFLOW__WEBSERVER__WEB_SERVER_WORKER_TIMEOUT="${AIRFLOW__WEBSERVER__WEB_SERVER_WORKER_TIMEOUT:-120}"

AIRFLOW_ROLE="${AIRFLOW_ROLE:-webserver}"
echo "ROLE: $AIRFLOW_ROLE"

# Configure DB (Neon)
if [[ -n "$NEON_DB_HOST" ]]; then
  : "${NEON_DB_PORT:=5432}"
  : "${NEON_DB_SSLMODE:=require}"
  export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="postgresql+psycopg2://${NEON_DB_USER}:${NEON_DB_PASSWORD}@${NEON_DB_HOST}:${NEON_DB_PORT}/${NEON_DB_NAME}?sslmode=${NEON_DB_SSLMODE}"
  echo "Using Neon Postgres DB"
fi

echo "===> Upgrading DB..."
airflow db upgrade

echo "===> Creating admin user..."
airflow users create \
  --role Admin \
  --username "${_AIRFLOW_WWW_USER_USERNAME:-airflow}" \
  --password "${_AIRFLOW_WWW_USER_PASSWORD:-airflow}" \
  --firstname Admin \
  --lastname User \
  --email admin@example.com || true

case "$AIRFLOW_ROLE" in
  scheduler)
    echo "Starting health server on :8080 ..."
    # Write a tiny Python HTTP server that always returns 200 OK (for /health or any path)
    cat << 'PY' > /tmp/health_server.py
import http.server
import socketserver

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")

    def log_message(self, format, *args):
        # Silence logs
        return

if __name__ == "__main__":
    with socketserver.TCPServer(("0.0.0.0", 8080), Handler) as httpd:
        httpd.serve_forever()
PY

    python /tmp/health_server.py >/dev/null 2>&1 &

    echo "Starting scheduler..."
    exec airflow scheduler
    ;;

  webserver)
    echo "Starting webserver..."
    exec airflow webserver --port "${PORT:-8080}" --hostname 0.0.0.0
    ;;

  *)
    echo "Unknown AIRFLOW_ROLE: $AIRFLOW_ROLE"
    exit 1
    ;;
esac
