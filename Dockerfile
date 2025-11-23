# Dockerfile
FROM apache/airflow:2.10.2-python3.11

# Switch to root to install system deps (if needed)
USER root

# Install build-essential etc if psycopg2 needs it (often already in base image)
RUN apt-get update && apt-get install -y \
    build-essential \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Switch back to airflow user
USER airflow

# Copy your requirements
COPY requirements.txt /requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r /requirements.txt

# Copy your entire project (including dags/ and data/)
COPY . /opt/airflow/

# Airflow looks at /opt/airflow/dags by default
ENV AIRFLOW_HOME=/opt/airflow

# Default command: start webserver + scheduler
CMD ["bash", "-c", "airflow db upgrade && airflow users create \
    --username admin --firstname Air --lastname Flow \
    --role Admin --email admin@example.com --password admin || true && \
    airflow webserver & airflow scheduler"]
