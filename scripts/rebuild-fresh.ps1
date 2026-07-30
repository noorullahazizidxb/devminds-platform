<#
.SYNOPSIS
  Recreate only the shared MySQL databases, rebuild every app without cache, and deploy.
.DESCRIPTION
  Docker Compose build never runs containers and cannot delete a named volume by itself.
  This wrapper performs the destructive database reset explicitly while preserving Redis,
  Elasticsearch, and both upload volumes.
#>
param(
  [ValidateSet("local", "production")]
  [string]$Env = "local"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$source = if ($Env -eq "production") { ".env.production" } else { ".env.local" }
if (-not (Test-Path $source)) {
  throw "Missing $source — create it from the repo template before deploying."
}

Write-Host "==> Using $source → .env ($Env)"
# Always write LF so Linux hosts never see COMPOSE_PROJECT_NAME=...\r
$text = [System.IO.File]::ReadAllText((Resolve-Path $source).Path) -replace "`r`n", "`n" -replace "`r", "`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $root ".env"), $text, $utf8NoBom)

$composeArgs = @("-f", "docker-compose.yml")
if ($Env -eq "local") {
  $composeArgs += @("-f", "docker-compose.local.yml")
}

Write-Warning "This deployment permanently deletes the Marketplace and Jobs MySQL databases."
Write-Host "==> Stopping the DevMinds stack..."
docker compose @composeArgs down --remove-orphans

Write-Host "==> Removing only the DevMinds MySQL volume..."
$mysqlVolumes = @(docker volume ls --quiet `
    --filter "label=com.docker.compose.project=devminds-platform" `
    --filter "label=com.docker.compose.volume=mysql-data")
foreach ($volume in $mysqlVolumes) {
  if ($volume) { docker volume rm $volume }
}

Write-Host "==> Rebuilding all application images without cache..."
docker compose @composeArgs build --no-cache

Write-Host "==> Starting the stack and recreating both databases..."
docker compose @composeArgs up -d --remove-orphans

Write-Host "==> Fresh deployment started. Follow readiness with: docker compose $($composeArgs -join ' ') ps"
Write-Host "==> Rebuilding all application images without cache..."
docker compose @composeArgs build --no-cache

Write-Host "==> Starting the stack and recreating both databases..."
docker compose @composeArgs up -d --remove-orphans

Write-Host "==> Fresh deployment started. Follow readiness with: docker compose $($composeArgs -join ' ') ps"
