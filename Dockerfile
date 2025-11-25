FROM apache/airflow:2.10.2-python3.11

# Switch to root for installs / file permissions
USER root

# Copy only requirements first (better cache)
COPY requirements.txt /opt/airflow/requirements.txt
RUN pip install --no-cache-dir -r /opt/airflow/requirements.txt

# Copy Airflow project
COPY . /opt/airflow/

# Copy our Railway entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown -R airflow: /opt/airflow

# Back to airflow user (required by the base image)
USER airflow

# Optional: you can also set some defaults here, but it's fine via env vars
# ENV AIRFLOW__CORE__LOAD_EXAMPLES=False

ENTRYPOINT ["/entrypoint.sh"]
