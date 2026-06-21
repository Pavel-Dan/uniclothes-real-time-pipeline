# Uniclos Bloc3 - declenche le DAG Airflow
$ErrorActionPreference = "Continue"
$DockerDir = (Join-Path (Join-Path $PSScriptRoot "..") "docker") | Resolve-Path

Write-Host "Declenchement DAG..."
Push-Location $DockerDir
docker compose exec airflow-scheduler airflow dags unpause uniclos_realtime_pipeline
docker compose exec airflow-scheduler airflow dags trigger uniclos_realtime_pipeline
Pop-Location
Write-Host "DAG declenche. Verifier http://localhost:8080"
