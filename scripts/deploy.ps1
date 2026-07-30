param(
  [ValidateSet("local", "production")]
  [string]$Env = "local"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$source = if ($Env -eq "production") {
  ".env.production"
}
else {
  ".env.local"
}

if (-not (Test-Path $source)) {
  throw "Missing $source - create it from the repo template before deploying."
}

Write-Host "==> Using $source -> .env ($Env)"
# Always write LF so Linux hosts never see COMPOSE_PROJECT_NAME=...\r
$text = [System.IO.File]::ReadAllText((Resolve-Path $source).Path) -replace "`r`n", "`n" -replace "`r", "`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $root ".env"), $text, $utf8NoBom)

$composeArgs = @("-f", "docker-compose.yml")
if ($Env -eq "local") {
  $composeArgs += @("-f", "docker-compose.local.yml")
  Write-Host "==> Local mode: apps on IP:ports (no Nginx)"
}
else {
  Write-Host "==> Production mode: Nginx + domains (Nginx on 127.0.0.1:8080/8443)"
}

docker compose @composeArgs config --quiet
if ($LASTEXITCODE -ne 0) {
  throw "Docker Compose configuration validation failed."
}

docker compose @composeArgs up -d --build --remove-orphans
if ($LASTEXITCODE -ne 0) {
  throw "Docker Compose deployment failed."
}

if ($Env -eq "local") {
  # Nginx stays defined in the base compose file but is profile-gated for local.
  # Stop any leftover edge proxy from a previous production run.
  # Docker writes "No stopped containers" to stderr; with $ErrorActionPreference=Stop
  # that becomes a terminating NativeCommandError — silence it intentionally.
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = "SilentlyContinue"
  try {
    docker compose -f docker-compose.yml stop nginx *>$null
    docker compose -f docker-compose.yml rm -f nginx *>$null
  }
  finally {
    $ErrorActionPreference = $prevEap
  }
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
else {
  Write-Host ""
  Write-Host "Production: DevMinds Nginx is on 127.0.0.1:8080 (HTTP) and 127.0.0.1:8443 (HTTPS)."
  Write-Host "If this VPS also hosts NewLinkAF (ticket.newlinkaf.com), start the edge gateway:"
  Write-Host "  cd gateway; docker compose up -d"
  Write-Host "See docs/GATEWAY.md for NewLinkAF port mapping (9080/9443) and routing details."
}
else {
  Write-Host ""
  Write-Host "Production: DevMinds Nginx is on 127.0.0.1:8080 (HTTP) and 127.0.0.1:8443 (HTTPS)."
  Write-Host "If this VPS also hosts NewLinkAF (ticket.newlinkaf.com), start the edge gateway:"
  Write-Host "  cd gateway; docker compose up -d"
  Write-Host "See docs/GATEWAY.md for NewLinkAF port mapping (9080/9443) and routing details."
}
  Write-Host "See docs/GATEWAY.md for NewLinkAF port mapping (9080/9443) and routing details."
}
