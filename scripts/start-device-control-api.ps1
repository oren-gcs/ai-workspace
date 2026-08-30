# Start device-control-api on 127.0.0.1:3920
$ErrorActionPreference = "Stop"
$apiDir = Join-Path $PSScriptRoot "..\services\device-control-api"
Push-Location $apiDir
try {
    if (-not (Test-Path "node_modules")) {
        Write-Host "[device-control-api] no node_modules — running node directly"
    }
    node server.js
} finally {
    Pop-Location
}
