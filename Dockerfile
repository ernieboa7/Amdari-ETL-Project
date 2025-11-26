FROM apache/airflow:2.10.2-python3.11

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
COPY . /opt/airflow/

# Make airflow own the project files
RUN chown -R airflow: /opt/airflow

# Copy our Railway entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown airflow: /entrypoint.sh

# Switch back to airflow to actually run Airflow
USER airflow

ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 8080
