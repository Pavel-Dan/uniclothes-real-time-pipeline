# Demarrage propre Bloc3
$ErrorActionPreference = "Continue"

$RootDir = (Join-Path $PSScriptRoot "..") | Resolve-Path
$DockerDir = Join-Path $RootDir "docker"
$EnvFile = Join-Path $DockerDir ".env"
$EnvExample = Join-Path $DockerDir ".env.example"

Push-Location $DockerDir

Write-Host "=== Uniclos Bloc3 - demarrage ===" -ForegroundColor Cyan

if (-not (Test-Path $EnvFile)) {
    Write-Host "[config] Creation docker/.env depuis .env.example"
    Copy-Item $EnvExample $EnvFile -Force
    Write-Host "         Renseignez les mots de passe dans docker/.env avant de continuer." -ForegroundColor Yellow
}

Write-Host "[config] Generation Grafana datasource depuis .env..."
powershell -ExecutionPolicy Bypass -File (Join-Path $RootDir "scripts\render_config.ps1")

Write-Host "[1/3] Arret stack et suppression volumes..."
docker compose down -v --remove-orphans | Out-Null

Write-Host "[2/3] Stack configuree via docker/.env"

Write-Host "[3/3] Lancement stack (attendre 2-3 min)..."
docker compose up -d --build

$exitCode = $LASTEXITCODE
Pop-Location

if ($exitCode -ne 0) {
    Write-Host "ERREUR docker compose" -ForegroundColor Red
    exit $exitCode
}

Write-Host ""
Write-Host "Stack lancee. Patientez 2-3 minutes puis:" -ForegroundColor Green
Write-Host "  cd docker"
Write-Host "  docker compose ps"
Write-Host ""
Write-Host "  Identifiants : voir docker/.env (AIRFLOW_ADMIN_*, GRAFANA_ADMIN_*, POSTGRES_*, MINIO_ROOT_*)"
Write-Host "  Airflow : http://localhost:8080"
Write-Host "  Grafana : http://localhost:3002"
Write-Host "  MinIO   : http://localhost:9011"
