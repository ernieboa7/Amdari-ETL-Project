FROM apache/airflow:2.10.2-python3.11

# Set Airflow home and make project importable as a Python package root
ENV AIRFLOW_HOME=/opt/airflow
ENV PYTHONPATH="/opt/airflow:${PYTHONPATH}"

# ---- Global lightweight defaults (can be overridden via Railway env vars) ----
# These help keep memory usage low on small containers.
ENV AIRFLOW__CORE__EXECUTOR=SequentialExecutor \
    AIRFLOW__CORE__PARALLELISM=1 \
    AIRFLOW__CORE__DAG_CONCURRENCY=1 \
    AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG=1 \
    AIRFLOW__SCHEDULER__MAX_THREADS=1 \
    AIRFLOW__WEBSERVER__WORKERS=1 \
    AIRFLOW__WEBSERVER__WEB_SERVER_WORKER_TIMEOUT=120

# Start as root to copy files / change ownership
USER root

# ---- Install Python dependencies as airflow user ----

# Copy requirements (if you have any extra packages)
COPY requirements.txt /requirements.txt

# Make airflow own the file
RUN chown airflow: /requirements.txt

# Switch to airflow BEFORE pip install (Airflow 2.10 requirement)
USER airflow

RUN pip install --no-cache-dir -r /requirements.txt

# ---- Copy project code (only what Airflow really needs) ----
USER root

WORKDIR ${AIRFLOW_HOME}

# Copy just DAGs (folder must exist in your repo)
COPY dags/ ./dags/

# If later you add plugins or extra src code, you can uncomment these:
# COPY plugins/ ./plugins/
# COPY src/ ./src/

# Ensure airflow owns the project files
RUN chown -R airflow: ${AIRFLOW_HOME}

# Copy our Railway entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown airflow: /entrypoint.sh

# Switch back to airflow to actually run Airflow
USER airflow

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
