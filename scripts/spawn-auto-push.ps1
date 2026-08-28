# spawn-auto-push.ps1 — Start auto-push.ps1 in a detached hidden process (returns immediately).
param([Parameter(Mandatory = $true)][string]$OnlyPath)
$ErrorActionPreference = "Stop"
$autoPush = Join-Path $PSScriptRoot "auto-push.ps1"
if (-not (Test-Path $autoPush)) { exit 0 }
$args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-WindowStyle", "Hidden",
    "-File", $autoPush,
    "-OnlyPath", $OnlyPath
)
Start-Process -FilePath "powershell.exe" -ArgumentList $args -WindowStyle Hidden | Out-Null
exit 0
