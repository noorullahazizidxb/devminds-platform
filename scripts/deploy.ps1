param(
  [ValidateSet("local", "production")]
  [string]$Env = "local"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$source = if ($Env -eq "production") {
  ".env.production"
} else {
  ".env.local"
}

if (-not (Test-Path $source)) {
  throw "Missing $source - create it from the repo template before deploying."
}

Write-Host "==> Using $source -> .env ($Env)"
Copy-Item -Path $source -Destination ".env" -Force

$composeArgs = @("-f", "docker-compose.yml")
if ($Env -eq "local") {
  $composeArgs += @("-f", "docker-compose.local.yml")
  Write-Host "==> Local mode: apps on IP:ports (no Nginx)"
} else {
  Write-Host "==> Production mode: Nginx + domains"
}

docker compose @composeArgs config --quiet
if ($LASTEXITCODE -ne 0) {
  throw "Docker Compose configuration validation failed."
}

docker compose @composeArgs up -d --build --remove-orphans
if ($LASTEXITCODE -ne 0) {
  throw "Docker Compose deployment failed."
}

docker compose @composeArgs ps

if ($Env -eq "local") {
  Write-Host ""
  Write-Host "Local URLs (same machine):"
  Write-Host "  Jobs UI:         http://127.0.0.1:3001"
  Write-Host "  Marketplace UI:  http://127.0.0.1:3002"
  Write-Host "  Jobs API:        http://127.0.0.1:4001/health"
  Write-Host "  Marketplace API: http://127.0.0.1:4002/api/health"
  Write-Host "Change LOCAL_PUBLIC_HOST in .env.local for LAN IP access, then redeploy."
}
