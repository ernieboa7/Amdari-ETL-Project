FROM apache/airflow:2.10.2-python3.11

# Set Airflow home and make project importable as a Python package root
ENV AIRFLOW_HOME=/opt/airflow
ENV PYTHONPATH="/opt/airflow:${PYTHONPATH}"

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

# ---- Copy project code ----
USER root

# Copy your whole project into /opt/airflow
COPY . ${AIRFLOW_HOME}

# Make airflow own the project files
RUN chown -R airflow: ${AIRFLOW_HOME}

# Copy our Railway entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown airflow: /entrypoint.sh

# Switch back to airflow to actually run Airflow
USER airflow

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
