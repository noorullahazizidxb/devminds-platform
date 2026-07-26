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

Write-Host "==> Clean complete."