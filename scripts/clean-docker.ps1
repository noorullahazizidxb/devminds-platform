<#
.SYNOPSIS
  Clean DevMinds Docker resources.
.PARAMETER Volumes
  Also remove named/anonymous volumes (docker compose down -v).
.PARAMETER Images
  Remove images built for this compose project.
.PARAMETER Prune
  Run docker system prune -f after teardown.
#>
param(
  [switch]$Volumes,
  [switch]$Images,
  [switch]$Prune
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$branch = (git branch --show-current).Trim()
Write-Host "==> Pulling latest for branch '$branch'..."
git pull --ff-only origin $branch
if ($LASTEXITCODE -ne 0) {
  throw "git pull failed for branch '$branch'."
}

Write-Host "==> Stopping compose stack..."
$downArgs = @("compose", "down", "--remove-orphans")
if ($Volumes) { $downArgs += "-v" }
if ($Images) { $downArgs += "--rmi"; $downArgs += "local" }
& docker @downArgs

if ($Prune) {
  Write-Host "==> Pruning unused Docker data..."
  docker system prune -f
  if ($Volumes) {
    docker volume prune -f
  }
}

Write-Host "==> Clean complete."s = @("compose", "--project-name", $ProjectName, "--env-file", ".env", "down", "--remove-orphans") }
if ($Volumes) { $downArgs += "-v" }
if ($Images) { $downArgs += "--rmi"; $downArgs += "local" }
& docker @downArgs

$devContainers = @(docker ps -aq --filter "name=^/devminds-")
if ($devContainers.Count -gt 0) {
  docker stop @devContainers | Out-Null
  docker rm -f @devContainers | Out-Null
}

if ($Prune) {
  Write-Host "==> Pruning unused Docker data..."
  docker system prune -f
  if ($Volumes) {
    docker volume prune -f
  }
}

Write-Host "==> Clean complete."
