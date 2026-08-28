# start-grok-bot-session.ps1 — Start Grok social bot in background with logging.
# Never prints secret values.
param(
    [switch]$Foreground
)

$ErrorActionPreference = "Stop"
$root = "F:\ai-workspace"
$projectLocal = "$root\projects\grok-social-bot\local"
$logDir = "$root\logs\grok-bot"
$stamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$logFile = Join-Path $logDir "session-$stamp.log"

# --- Device access check first ---
Write-Host "[grok-bot] Running device-access-check..."
& "$root\scripts\device-access-check.ps1" | Out-Null

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

if (-not (Test-Path $projectLocal)) {
    Write-Error "Project local path not found: $projectLocal"
}

Push-Location $projectLocal
try {
    if (-not (Test-Path "node_modules")) {
        Write-Host "[grok-bot] npm install..."
        npm install 2>&1 | Tee-Object -FilePath $logFile -Append
    }

    if (-not (Test-Path ".env")) {
        if (Test-Path ".env.example") {
            Copy-Item ".env.example" ".env"
            Write-Host "[grok-bot] Created .env from .env.example — configure keys before production use"
        } else {
            Write-Warning "[grok-bot] No .env — copy .env.example and set XAI_API_KEY etc."
        }
    }

    $npmArgs = @("run", "start")
    if ($Foreground) {
        Write-Host "[grok-bot] Foreground mode — log: $logFile"
        npm @npmArgs 2>&1 | Tee-Object -FilePath $logFile
    } else {
        Write-Host "[grok-bot] Starting in background — log: $logFile"
        $proc = Start-Process -FilePath "npm" -ArgumentList @("run", "start") `
            -WorkingDirectory $projectLocal `
            -RedirectStandardOutput $logFile `
            -RedirectStandardError (Join-Path $logDir "session-$stamp.err.log") `
            -WindowStyle Hidden `
            -PassThru
        Write-Host "[grok-bot] PID $($proc.Id) | tail: Get-Content -Wait $logFile"
    }
} finally {
    Pop-Location
}

Write-Host "[grok-bot] Dedicated window: code --new-window F:\ai-workspace\projects\grok-social-bot"
