-- Airflow metadata database (created during PostgreSQL first init)
SELECT 'CREATE DATABASE airflow OWNER uniclothes'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'airflow')\gexec

GRANT ALL PRIVILEGES ON DATABASE airflow TO uniclothes;
