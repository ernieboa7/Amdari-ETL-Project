# Amdari-ETL-Project
3. Full README.md (ready for GitHub)

Here is a professional README tailored to your project:

 Retail Analytics ETL Pipeline with Apache Airflow

Automated Extract → Transform → Load pipeline deployed on Render, loading property sales data into Neon PostgreSQL.

 Overview

This project implements a production-ready ETL pipeline for cleaning and loading property listing data into a Neon PostgreSQL cloud database.

It uses:

Apache Airflow for workflow orchestration

Pandas for data cleaning/transformation

Psycopg2 for database loading

Render for cloud deployment

Neon PostgreSQL as the destination data warehouse

📂 Project Structure
your-etl-project/
├── Dockerfile
├── requirements.txt
├── .gitignore
├── .env.example
│
├── dags/
│   └── retail_etl_dag.py
│
├── etl/
│   ├── transform.py
│   └── load.py
│
├── data/
│   ├── properties.csv
│   └── clean_properties.csv



⚙️ Environment Variables

Create a .env file (not committed to GitHub):

NEON_DB_HOST=...
NEON_DB_PORT=5432
NEON_DB_NAME=...
NEON_DB_USER=...
NEON_DB_PASSWORD=...
NEON_DB_SSLMODE=require


A safe template exists as .env.example.

🐳 Docker Build (Local test)
docker build -t retail-airflow .
docker run -p 8080:8080 --env-file .env retail-airflow


Then open Airflow UI:

http://localhost:8080

☁️ Deploy to Render

Push the repo to GitHub

Create a Render Web Service

Select Dockerfile

Add environment variables from .env

Deploy → Visit Airflow UI

Trigger the DAG: retail_properties_etl

🔄 ETL Workflow
1. Extract

Ensures raw properties.csv exists

Located in data/ folder

2. Transform

Fixes column misalignment

Cleans missing/invalid values

Converts date, price, SQFT

Adds listing_id

Saves clean_properties.csv

3. Load

Creates destination table properties

Upserts rows using ON CONFLICT

Loaded into Neon PostgreSQL

4. Verify

Compares DB row count vs cleaned CSV row count

Fails the DAG if mismatch occurs

Ensures data quality

 Data Quality Checks

The DAG includes a verification task that:

Reads clean_properties.csv

Counts expected rows

Queries SELECT COUNT(*) FROM properties

Raises an Airflow error if counts don't match

🧾 Requirements
apache-airflow==2.10.2
pandas
psycopg2-binary
SQLAlchemy
python-dotenv

📜 License

MIT License 





