# smart-device-op.ps1 — Route device ops to local scripts first; escalate only on failure.
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet("status", "start", "stop", "push", "diagnose")]
  [string]$Operation,

  [string]$Title = "Brain",
  [string]$Message = "",
  [switch]$SkipIfRunning,
  [switch]$OpenUI,
  [switch]$Json
)

$ErrorActionPreference = "Continue"
$Root = "F:\ai-workspace"
$RoutingDoc = Join-Path $Root "docs\AGENT-ROUTING.md"

function Write-Escalation([string]$Target, [string]$Reason) {
  Write-Host ""
  Write-Host "=== ESCALATE ===" -ForegroundColor Yellow
  Write-Host "Target: $Target"
  Write-Host "Reason: $Reason"
  Write-Host "Routing: $RoutingDoc"
}

function Invoke-ScriptChecked {
  param(
    [string]$Label,
    [string]$ScriptPath,
    [hashtable]$ScriptArgs = @{}
  )
  if (-not (Test-Path $ScriptPath)) {
    return @{ Ok = $false; ExitCode = 127; Note = "missing: $ScriptPath" }
  }
  $argText = (@($ScriptArgs.GetEnumerator() | ForEach-Object {
    if ($_.Value -is [bool] -and $_.Value) { "-$($_.Key)" } else { "-$($_.Key) $($_.Value)" }
  })) -join ' '
  Write-Host "[$Label] $ScriptPath $argText" -ForegroundColor Cyan
  & $ScriptPath @ScriptArgs
  $code = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
  return @{ Ok = ($code -eq 0); ExitCode = $code; Note = "exit=$code" }
}

switch ($Operation) {
  "status" {
    $r = Invoke-ScriptChecked -Label "status" -ScriptPath (Join-Path $Root "scripts\status-all.ps1") -ScriptArgs $(if ($Json) { @{ Json = $true } } else { @{} })
    if (-not $r.Ok) {
      Write-Escalation -Target "Cursor agent (composer-2.5-fast) + device-access-resolver" -Reason "status-all reported down services or device-access failures"
    }
    exit $r.ExitCode
  }

  "start" {
    $startArgs = @{}
    if ($OpenUI) { $startArgs.OpenUI = $true } else { $startArgs.NoOpen = $true }
    if ($SkipIfRunning) { $startArgs.SkipIfRunning = $true }
    $r = Invoke-ScriptChecked -Label "start" -ScriptPath (Join-Path $Root "scripts\start-all-local.ps1") -ScriptArgs $startArgs
    if (-not $r.Ok) {
      Write-Escalation -Target "Cursor agent (composer-2.5-fast) + device-access-resolver" -Reason "start-all-local failed — check docker, npm paths, or port conflicts"
    }
    exit $r.ExitCode
  }

  "stop" {
    $stopped = $false
    $dp = "F:\DevSecOps\projects\doc-power-local-k8s"
    if (Test-Path (Join-Path $dp "docker-compose.yml")) {
      Write-Host "[stop] doc-power docker compose down" -ForegroundColor Cyan
      Push-Location $dp
      docker compose down 2>&1 | Out-Null
      Pop-Location
      if ($LASTEXITCODE -eq 0) { $stopped = $true }
    }
    $ports = @(3000, 3001, 3002, 3003, 3004, 3007, 3847, 8000)
    $stillUp = @()
    foreach ($p in $ports) {
      try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect("127.0.0.1", $p, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(300) -and $tcp.Connected) {
          $stillUp += $p
        }
        $tcp.Close()
      } catch {}
    }
    if ($stillUp.Count -gt 0) {
      Write-Host ("[stop] npm dev servers still listening on: " + ($stillUp -join ", "))
      Write-Escalation -Target "Cursor agent (composer-2.5-fast) shell subagent" -Reason "no stop-all script for npm dev processes; manual Stop-Process or close terminals"
      exit 1
    }
    if ($stopped) { exit 0 }
    Write-Escalation -Target "Cursor agent (composer-2.5-fast)" -Reason "nothing to stop and doc-power compose missing"
    exit 1
  }

  "push" {
    if (-not $Message) {
      Write-Host "Usage: smart-device-op.ps1 push -Message 'your alert text' [-Title 'Brain']" -ForegroundColor Red
      exit 2
    }
    $notify = "C:\Users\oren\.claude\brain\scripts\brain-notify.ps1"
    $r = Invoke-ScriptChecked -Label "push" -ScriptPath $notify -ScriptArgs @{ Title = $Title; Message = $Message }
    if (-not $r.Ok) {
      Write-Escalation -Target "Cowork (Claude Desktop)" -Reason "brain-notify.ps1 failed — Cowork PushNotification MCP or check phone-config.json / ntfy topic"
    }
    exit $r.ExitCode
  }

  "diagnose" {
    $diagArgs = @{}
    if ($Json) { $diagArgs.Json = $true }
    $r = Invoke-ScriptChecked -Label "diagnose" -ScriptPath (Join-Path $Root "scripts\device-access-check.ps1") -ScriptArgs $diagArgs
    if (-not $r.Ok) {
      Write-Escalation -Target "Cursor agent (composer-2.5-fast) + device-access-resolver skill" -Reason "device-access-check reported failures — run sync-gh-auth.ps1 or see DEVICE-ACCESS-PLAYBOOK.md"
    }
    exit $r.ExitCode
  }
}

