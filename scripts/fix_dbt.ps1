# Corrige schemas dbt + recharge fact_sales dans dwh.fact_sales
# Usage (depuis n'importe quel dossier) :
#   powershell -ExecutionPolicy Bypass -File "c:\Users\pavel\Downloads\Master Thesis v2\Bloc3_Real_time_data_pipeline\scripts\fix_dbt.ps1"
# Ou depuis la racine du projet :
#   powershell -ExecutionPolicy Bypass -File scripts\fix_dbt.ps1
$ErrorActionPreference = "Continue"
$DockerDir = (Join-Path (Join-Path $PSScriptRoot "..") "docker") | Resolve-Path
Push-Location $DockerDir

Write-Host "Extension dim_date (dates manquantes)..."
docker compose exec postgres psql -U uniclothes -d uniclothes -c "INSERT INTO dwh.dim_date (date_key, full_date, day_of_week, day_name, week_of_year, month_num, month_name, quarter_num, year_num) SELECT TO_CHAR(d, 'YYYYMMDD')::INTEGER, d::DATE, EXTRACT(DOW FROM d)::INTEGER, TO_CHAR(d, 'Day'), EXTRACT(WEEK FROM d)::INTEGER, EXTRACT(MONTH FROM d)::INTEGER, TO_CHAR(d, 'Month'), EXTRACT(QUARTER FROM d)::INTEGER, EXTRACT(YEAR FROM d)::INTEGER FROM generate_series(CURRENT_DATE - 30, CURRENT_DATE + 30, '1 day'::interval) AS d ON CONFLICT (full_date) DO NOTHING;"

Write-Host "Recreation dwh.fact_sales (alignee sur le modele dbt, sans sales_key)..."
$SqlFix = (Join-Path (Join-Path $PSScriptRoot "..") "sql\fix_fact_sales.sql") | Resolve-Path
Get-Content $SqlFix -Raw | docker compose exec -T postgres psql -U uniclothes -d uniclothes

Write-Host "Nettoyage anciens objets dbt (schemas incorrects)..."
docker compose exec postgres psql -U uniclothes -d uniclothes -c "DROP TABLE IF EXISTS staging_dwh.fact_sales CASCADE; DROP VIEW IF EXISTS staging_staging.stg_orders CASCADE; DROP VIEW IF EXISTS staging_staging.stg_customers CASCADE;"

Write-Host "Relance dbt..."
docker compose exec airflow-scheduler bash -c "cd /opt/airflow/dbt && dbt run --profiles-dir . --project-dir . --select staging+"

Write-Host ""
Write-Host "Verification:"
docker compose exec postgres psql -U uniclothes -d uniclothes -c "SELECT COUNT(*) AS fact_sales FROM dwh.fact_sales;"
docker compose exec postgres psql -U uniclothes -d uniclothes -c "SELECT COUNT(*) AS pending FROM raw.streaming_orders WHERE processed = false;"

Pop-Location
