# Dockerfile
FROM apache/airflow:2.10.2-python3.11

# Use root to install OS-level deps and set up files
USER root

# Install build-essential etc if psycopg2 or other libs need it
RUN apt-get update && apt-get install -y \
    build-essential \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Python requirements and install them
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

# Copy the start script and make it executable
COPY render-start.sh /opt/airflow/render-start.sh
RUN chmod 755 /opt/airflow/render-start.sh

# Copy your entire project (including dags/, plugins/, etc.)
COPY . /opt/airflow/

# Make sure the airflow user owns the project directory
RUN chown -R airflow: /opt/airflow

# Airflow defaults
ENV AIRFLOW_HOME=/opt/airflow

# Drop back to the airflow user for runtime
USER airflow

# Default CMD – Render will override with Docker Command if needed
CMD ["/opt/airflow/render-start.sh"]
