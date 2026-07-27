<#
.SYNOPSIS
  Recreate only the shared MySQL databases, rebuild every app without cache, and deploy.
.DESCRIPTION
  Docker Compose build never runs containers and cannot delete a named volume by itself.
  This wrapper performs the destructive database reset explicitly while preserving Redis,
  Elasticsearch, and both upload volumes.
#>
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Warning "This deployment permanently deletes the Marketplace and Jobs MySQL databases."
Write-Host "==> Stopping the DevMinds stack..."
docker compose down --remove-orphans

Write-Host "==> Removing only the DevMinds MySQL volume..."
$mysqlVolumes = @(docker volume ls --quiet `
  --filter "label=com.docker.compose.project=devminds-platform" `
  --filter "label=com.docker.compose.volume=mysql-data")
foreach ($volume in $mysqlVolumes) {
  if ($volume) { docker volume rm $volume }
}

Write-Host "==> Rebuilding all application images without cache..."
docker compose build --no-cache

Write-Host "==> Starting the stack and recreating both databases..."
docker compose up -d --remove-orphans

Write-Host "==> Fresh deployment started. Follow readiness with: docker compose ps"