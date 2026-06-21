# Genere les fichiers de config a partir de docker/.env
$ErrorActionPreference = "Stop"
$DockerDir = (Join-Path (Join-Path $PSScriptRoot "..") "docker") | Resolve-Path
$EnvFile = Join-Path $DockerDir ".env"
$Template = Join-Path $DockerDir "grafana\provisioning\datasources\datasource.yml.template"
$Output = Join-Path $DockerDir "grafana\provisioning\datasources\datasource.yml"

if (-not (Test-Path $EnvFile)) {
    Write-Error "Fichier manquant: $EnvFile (copier .env.example vers .env)"
}

$vars = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line -match "^([^=]+)=(.*)$") {
        $vars[$matches[1]] = $matches[2]
    }
}

$content = Get-Content $Template -Raw
foreach ($key in $vars.Keys) {
    $content = $content.Replace('${' + $key + '}', $vars[$key])
}

Set-Content -Path $Output -Value $content -Encoding UTF8
Write-Host "Config generee: datasource Grafana"
