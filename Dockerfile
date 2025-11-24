# Dockerfile
FROM apache/airflow:2.10.2-python3.11

# 1) Use root to install OS-level dependencies and prepare files
USER root

# Install build tools (for psycopg2 and similar)
RUN apt-get update && apt-get install -y \
    build-essential \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy your whole project into /opt/airflow
COPY . /opt/airflow/

# Make sure the start script is executable
RUN chmod 755 /opt/airflow/render-start.sh

# Ensure airflow user owns the project directory
RUN chown -R airflow: /opt/airflow

# 2) Switch to airflow user for all Python / pip work (required by Airflow image)
USER airflow

# Install Python dependencies as 'airflow' user
RUN pip install --no-cache-dir -r /opt/airflow/requirements.txt

# 3) Airflow config and default command
ENV AIRFLOW_HOME=/opt/airflow

# Default CMD – Render will override with Docker Command if needed, but this works locally too
CMD ["/opt/airflow/render-start.sh"]
