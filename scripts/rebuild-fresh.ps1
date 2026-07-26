<#
.SYNOPSIS
  Tear down volumes, rebuild images with --no-cache, and start the stack.
#>
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "==> Bringing stack down (with volumes)..."
docker compose down -v --remove-orphans

Write-Host "==> Building images (--no-cache)..."
docker compose build --no-cache

Write-Host "==> Starting stack..."
docker compose up -d

Write-Host "==> Rebuild-fresh complete. Check: docker compose ps"