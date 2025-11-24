FROM apache/airflow:2.10.2-python3.11

# Use root only for file permissions
USER root

# Copy project into Airflow home
COPY . /opt/airflow/

# Make start scripts executable and set ownership
RUN chmod 755 /opt/airflow/render-start-web.sh /opt/airflow/render-start-scheduler.sh \
    && chown -R airflow: /opt/airflow

# Switch to airflow user (required by base image)
USER airflow

ENV AIRFLOW_HOME=/opt/airflow

# Install your Python deps (Airflow itself is already in the base image)
RUN pip install --no-cache-dir -r /opt/airflow/requirements.txt

# Default command: webserver (Render overrides this anyway via dockerCommand)
CMD ["/opt/airflow/render-start-web.sh"]
