# Applique les ameliorations Phase A sur une base deja initialisee (sans reset)
$ErrorActionPreference = "Continue"
$RootDir = (Join-Path $PSScriptRoot "..") | Resolve-Path
$DockerDir = Join-Path $RootDir "docker"
$SqlFile = Join-Path $RootDir "sql\apply_phase_a.sql"

Push-Location $DockerDir
Write-Host "Application Phase A (RBAC analyst + RGPD streaming)..."
Get-Content $SqlFile -Raw | docker compose exec -T postgres psql -U uniclothes -d uniclothes
Pop-Location

Write-Host ""
Write-Host "Verification RBAC analyst:"
Push-Location $DockerDir

$denied = docker compose exec postgres psql -U uniclothes_analyst -d uniclothes -c "SELECT COUNT(*) FROM dwh.fact_sales;" 2>&1
if ($denied -match "permission denied") {
    Write-Host "  [OK] fact_sales refuse pour uniclothes_analyst (moindre privilege)"
} else {
    Write-Host "  [ATTENTION] uniclothes_analyst peut encore lire fact_sales"
    Write-Host $denied
}

$allowed = docker compose exec postgres psql -U uniclothes_analyst -d uniclothes -c "SELECT COUNT(*) FROM dwh.v_sales_analytics;" 2>&1
if ($allowed -match "^\s*count") {
    Write-Host "  [OK] v_sales_analytics accessible pour uniclothes_analyst"
    Write-Host $allowed
} else {
    Write-Host "  [ERREUR] acces v_sales_analytics"
    Write-Host $allowed
}

Pop-Location
