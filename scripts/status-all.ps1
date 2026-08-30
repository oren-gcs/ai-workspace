# status-all.ps1 — Pretty status table for local apps + MCPs (reads running-services.json)
param(
    [switch]$Json,
    [switch]$SkipDeviceCheck
)

$ErrorActionPreference = "Continue"
$Root = "F:\ai-workspace"
$ProbeScript = Join-Path $Root "scripts\get-running-services.ps1"
$RegistryFile = Join-Path $Root "config\running-services.json"

if (Test-Path $ProbeScript) {
    & $ProbeScript -Quiet 2>&1 | Out-Null
}

if (-not (Test-Path $RegistryFile)) {
    Write-Host "Registry not found: $RegistryFile"
    exit 0
}

$data = Get-Content -Raw $RegistryFile | ConvertFrom-Json
$rows = @()

if ($data.services -is [System.Array]) {
    foreach ($s in $data.services) {
        $ready = ($s.status -eq "running") -or (($s.listening -eq $true) -and ($s.healthOk -eq $true))
        $statusLabel = switch ($s.status) {
            "running"   { "UP" }
            "listening" { "LISTEN (no health)" }
            "stopped"   { "DOWN" }
            default     { $s.status }
        }
        $simultaneous = if ($s.parallel -and $ready) { "yes" } elseif ($s.parallel) { "when up" } else { "no" }

        $rows += [PSCustomObject]@{
            Project                    = $s.id
            Status                     = $statusLabel
            Port                       = if ($s.port) { $s.port } else { "-" }
            PID                        = if ($s.pid) { $s.pid } else { "-" }
            URL                        = if ($s.url) { $s.url } else { "-" }
            'Can work simultaneously?' = $simultaneous
        }
    }
} else {
    foreach ($prop in $data.services.PSObject.Properties) {
        $s = $prop.Value
        $rows += [PSCustomObject]@{
            Project                    = $prop.Name
            Status                     = if ($s.running) { "UP" } else { "DOWN" }
            Port                       = "-"
            PID                        = if ($s.pid) { $s.pid } else { "-" }
            URL                        = "-"
            'Can work simultaneously?' = if ($s.running) { "yes" } else { "when up" }
        }
    }
}

$upCount = @($rows | Where-Object { $_.Status -eq "UP" }).Count
$readyParallel = @($rows | Where-Object { $_.'Can work simultaneously?' -eq "yes" }).Count

$deviceOk = $true
if (-not $SkipDeviceCheck) {
    $dac = Join-Path $Root "scripts\device-access-check.ps1"
    if (Test-Path $dac) {
        $jsonText = & $dac -Json 2>$null
        if ($jsonText) {
            $checks = $jsonText | ConvertFrom-Json
            foreach ($prop in $checks.PSObject.Properties) {
                if ($prop.Value.status -eq "fail") { $deviceOk = $false }
            }
        }
    }
}

if ($Json) {
    @{
        updatedAt      = $data.updatedAt
        services       = $rows
        upCount        = $upCount
        readyParallel  = $readyParallel
        deviceAccessOk = $deviceOk
    } | ConvertTo-Json -Depth 4
} else {
    Write-Host ""
    Write-Host ("Local apps + MCPs — {0} up, {1} ready for parallel use" -f $upCount, $readyParallel)
    Write-Host ("Registry: {0}" -f $RegistryFile)
    Write-Host ("Updated:  {0}" -f $data.updatedAt)
    if (-not $deviceOk) { Write-Host "Device access: issues detected (run device-access-check.ps1)" -ForegroundColor Yellow }
    Write-Host ""
    $rows | Format-Table -AutoSize
    Write-Host "Tip: run status-all before start-all-local to avoid duplicate launches."
    Write-Host "     start-all-local.ps1 -SkipIfRunning (default) skips services already up."
}

$global:StatusAllRows = $rows
exit 0
