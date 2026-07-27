$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

docker compose config --quiet
docker compose up -d --build --remove-orphans
docker compose ps