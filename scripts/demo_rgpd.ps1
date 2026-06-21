# Demo RGPD : droit d acces puis effacement (client de test du seed)
param(
    [string]$Email = "anais.thomas0@email.com"
)

$ErrorActionPreference = "Continue"
$RootDir = (Join-Path $PSScriptRoot "..") | Resolve-Path
$DockerDir = Join-Path $RootDir "docker"

function Invoke-Psql {
    param(
        [string]$User,
        [string]$Sql
    )
    Push-Location $DockerDir
    docker compose exec postgres psql -U $User -d uniclothes -c $Sql
    Pop-Location
}

Write-Host "=== Demo RGPD Uniclos ($Email) ==="
Write-Host ""

Write-Host "1) Comptages avant:"
Invoke-Psql -User "uniclothes" -Sql "SELECT COUNT(*) AS dim_customer FROM dwh.dim_customer WHERE LOWER(TRIM(email)) = LOWER(TRIM('$Email'));"
Invoke-Psql -User "uniclothes" -Sql "SELECT COUNT(*) AS streaming_orders FROM raw.streaming_orders WHERE LOWER(TRIM(customer_email)) = LOWER(TRIM('$Email'));"
Invoke-Psql -User "uniclothes" -Sql "SELECT COUNT(*) AS fact_sales FROM dwh.fact_sales fs JOIN dwh.dim_customer dc ON fs.customer_key = dc.customer_key WHERE LOWER(TRIM(dc.email)) = LOWER(TRIM('$Email'));"

Write-Host ""
Write-Host "2) Droit d acces (role DPO):"
Invoke-Psql -User "uniclothes_dpo" -Sql "SELECT * FROM audit.export_customer_gdpr('$Email');"

Write-Host ""
Write-Host "3) Droit a l effacement (role DPO):"
Invoke-Psql -User "uniclothes_dpo" -Sql "SELECT * FROM audit.delete_customer_gdpr('$Email');"

Write-Host ""
Write-Host "4) Comptages apres:"
Invoke-Psql -User "uniclothes" -Sql "SELECT COUNT(*) AS dim_customer FROM dwh.dim_customer WHERE LOWER(TRIM(email)) = LOWER(TRIM('$Email'));"
Invoke-Psql -User "uniclothes" -Sql "SELECT COUNT(*) AS streaming_orders FROM raw.streaming_orders WHERE LOWER(TRIM(customer_email)) = LOWER(TRIM('$Email'));"
Invoke-Psql -User "uniclothes" -Sql "SELECT request_type, status, notes FROM audit.gdpr_requests WHERE LOWER(TRIM(customer_email)) = LOWER(TRIM('$Email')) ORDER BY request_id DESC LIMIT 2;"

Write-Host ""
Write-Host "Demo terminee. Relancer start.ps1 ou recharger les seeds pour restaurer le client de test."
