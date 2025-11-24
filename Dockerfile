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

# Set Airflow home
ENV AIRFLOW_HOME=/opt/airflow

# Install your Python deps (Airflow itself is already in the base image)
RUN pip install --no-cache-dir -r /opt/airflow/requirements.txt

# Use dumb-init as PID 1, then run our script
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/opt/airflow/render-start.sh"]
