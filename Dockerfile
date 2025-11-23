# Dockerfile
FROM apache/airflow:2.10.2-python3.11

# Use root only to install OS-level dependencies
USER root

# Install build-essential etc if psycopg2 needs it (often already in base image)
RUN apt-get update && apt-get install -y \
    build-essential \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Switch back to airflow user for Python stuff (required by Airflow image)
USER airflow

# Copy your requirements
COPY requirements.txt /requirements.txt

# Install Python dependencies as 'airflow' user
RUN pip install --no-cache-dir -r /requirements.txt

# Copy the start script and make it executable
COPY render-start.sh /opt/airflow/render-start.sh
RUN chmod +x /opt/airflow/render-start.sh

# Copy your entire project (including dags/ and data/)
COPY . /opt/airflow/

# Airflow looks at /opt/airflow/dags by default
ENV AIRFLOW_HOME=/opt/airflow

# Default CMD – Render will override with Docker Command, but this works locally too
CMD ["/opt/airflow/render-start.sh"]
