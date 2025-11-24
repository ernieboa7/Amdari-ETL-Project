FROM apache/airflow:2.10.2-python3.11

# Use root only for file permissions
USER root

# Copy project into Airflow home
COPY . /opt/airflow/

# Make start script executable and set ownership
RUN chmod 755 /opt/airflow/render-start.sh \
    && chown -R airflow: /opt/airflow

# Switch to airflow user (required by base image)
USER airflow

ENV AIRFLOW_HOME=/opt/airflow

# Install only your Python deps
# (optional but leaner: remove apache-airflow from requirements.txt,
# the base image already has it)
RUN pip install --no-cache-dir -r /opt/airflow/requirements.txt

# Default command – works locally; Render overrides with dockerCommand,
# but this is safe to keep.
CMD ["/opt/airflow/render-start.sh"]
