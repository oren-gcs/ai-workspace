# device-control.ps1 — Unified Device & App Control CLI
# Usage: device-control.ps1 <status|start|stop|restart|open|apps> [id|all] [-OpenUI] [-ForceStart]
param(
    [Parameter(Position = 0)]
    [ValidateSet("status", "start", "stop", "restart", "open", "apps")]
    [string]$Action = "status",

    [Parameter(Position = 1)]
    [string]$Target = "",

    [switch]$OpenUI,
    [switch]$ForceStart,
    [switch]$Json
)

$ErrorActionPreference = "Continue"
$Root = "F:\ai-workspace"
$ConfigDir = Join-Path $Root "config"
$AppsFile = Join-Path $ConfigDir "device-apps.json"
$RunningFile = Join-Path $ConfigDir "running-services.json"
$LogDir = Join-Path $Root "logs\device-control"
$ProtectedProcesses = @("Code", "Cursor", "devenv", "WindowsTerminal")

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Test-PortListening {
    param([int]$Port, [string]$Address = "127.0.0.1")
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect($Address, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(500)
        if ($ok -and $tcp.Connected) { $tcp.Close(); return $true }
        $tcp.Close()
    } catch {}
    return $false
}

function Test-HttpOk {
    param([string]$Url, [int]$TimeoutSec = 3)
    if (-not $Url) { return $false }
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500)
    } catch { return $false }
}

function Get-ListenerPid {
    param([int]$Port, [string]$Address = "127.0.0.1")
    $line = netstat -ano | Select-String -Pattern ("TCP\s+" + [regex]::Escape($Address) + ":" + $Port + "\s")
    if (-not $line) { return $null }
    $parts = ($line.ToString().Trim() -split "\s+")
    if ($parts.Length -ge 5) { return [int]$parts[-1] }
    return $null
}

function Get-ProtectedProcessName {
    param([int]$Pid)
    try {
        $proc = Get-Process -Id $Pid -ErrorAction Stop
        return $proc.ProcessName
    } catch { return $null }
}

function Test-IsProtectedPid {
    param([int]$Pid)
    $name = Get-ProtectedProcessName -Pid $Pid
    if (-not $name) { return $false }
    foreach ($p in $ProtectedProcesses) {
        if ($name -like "*$p*") { return $true }
    }
    return $false
}

function Get-DeviceApps {
    if (-not (Test-Path $AppsFile)) {
        Write-Error "Missing $AppsFile"
        exit 1
    }
    $cfg = Get-Content $AppsFile -Raw | ConvertFrom-Json
    return @($cfg.apps)
}

function Get-AppById {
    param([string]$Id)
    $apps = Get-DeviceApps
    $app = $apps | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $app) {
        Write-Error "Unknown app id: $Id. Run: device-control.ps1 apps"
        exit 1
    }
    return $app
}

function Test-AppRunning {
    param($App)
    if ($App.id -eq "brain-mcp") {
        $smoke = "C:\Users\oren\.claude\brain\mcp\smoke.mjs"
        if (-not (Test-Path $smoke)) { return @{ Running = $false; Detail = "smoke missing" } }
        $job = Start-Job -ScriptBlock {
            param($p)
            $lines = @(& node $p 2>&1)
            ($lines | ForEach-Object { "$_" }) -join [Environment]::NewLine
        } -ArgumentList $smoke
        $completed = Wait-Job $job -Timeout 8
        if (-not $completed) {
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            return @{ Running = $false; Detail = "smoke timeout"; Pid = $null }
        }
        $text = Receive-Job $job
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        $ok = ($text -match "INIT: ok") -and ($text -match "STATUS: ok")
        return @{ Running = $ok; Detail = $(if ($ok) { "stdio-ready" } else { "smoke failed" }); Pid = $null }
    }
    if ($App.id -eq "doc-power") {
        $listen = Test-PortListening 3000
        $http = if ($listen) { Test-HttpOk $App.healthUrl } else { $false }
        $listenerPid = Get-ListenerPid 3000
        return @{ Running = ($listen -or $http); Detail = "port3000=$listen http=$http"; Pid = $listenerPid }
    }
    if ($App.port) {
        $listen = Test-PortListening $App.port
        $http = if ($listen -and $App.healthUrl) { Test-HttpOk $App.healthUrl } else { $false }
        $listenerPid = Get-ListenerPid $App.port
        return @{ Running = ($listen -or $http); Detail = "port=$($App.port) listen=$listen http=$http"; Pid = $listenerPid }
    }
    return @{ Running = $false; Detail = "no port configured"; Pid = $null }
}

function Save-RunningServices {
    param([hashtable]$States)
    $obj = @{
        generatedAt = (Get-Date).ToString("o")
        deviceControlVersion = "1.0.0"
        services = $States
    }
    $obj | ConvertTo-Json -Depth 6 | Set-Content $RunningFile -Encoding UTF8
}

function Get-GitHealth {
    $checks = [ordered]@{}
    gh auth status 2>&1 | Out-Null
    $checks["gh_auth"] = if ($LASTEXITCODE -eq 0) { "ok" } else { "fail" }
    $login = (gh api user -q .login 2>$null)
    $checks["gh_user"] = if ($login) { $login } else { "unknown" }
    try {
        docker info 2>$null | Out-Null
        $checks["docker"] = if ($LASTEXITCODE -eq 0) { "ok" } else { "down" }
    } catch { $checks["docker"] = "down" }
    return $checks
}

function Invoke-DeviceStatus {
    $apps = Get-DeviceApps
    $rows = @()
    $stateMap = @{}

    foreach ($app in $apps) {
        $r = Test-AppRunning -App $app
        $rows += [PSCustomObject]@{
            Id       = $app.id
            Name     = $app.name
            Type     = $app.type
            Running  = $r.Running
            Port     = $app.port
            Pid      = $r.Pid
            Detail   = $r.Detail
            Url      = $app.url
        }
        $stateMap[$app.id] = @{
            running = $r.Running
            pid     = $r.Pid
            detail  = $r.Detail
            checked = (Get-Date).ToString("o")
        }
    }

    Save-RunningServices -States $stateMap
    $probeScript = Join-Path $Root "scripts\get-running-services.ps1"
    if (Test-Path $probeScript) { & $probeScript -Quiet 2>&1 | Out-Null }
    $git = Get-GitHealth

    if ($Json) {
        @{
            apps = $rows
            git  = $git
            mcps = (Get-Content (Join-Path $Root "mcp\registry.json") -Raw | ConvertFrom-Json).servers
        } | ConvertTo-Json -Depth 8
        return
    }

    Write-Host "=== Device Control Status ===" -ForegroundColor Cyan
    Write-Host ("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
    Write-Host ""
    $rows | Format-Table -AutoSize
    Write-Host "Git / Docker health:" -ForegroundColor Cyan
    foreach ($k in $git.Keys) {
        Write-Host ("  {0}: {1}" -f $k, $git[$k])
    }
    Write-Host ""
    Write-Host "State: $RunningFile"
}

function Start-BackgroundApp {
    param($App)
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outLog = Join-Path $LogDir ($App.id + "-" + $stamp + ".log")
    $errLog = Join-Path $LogDir ($App.id + "-" + $stamp + ".err.log")

    if ($App.startCommand -like "note:*") {
        Write-Host ("[" + $App.id + "] " + $App.startCommand.Substring(5))
        return @{ Started = $false; Note = $App.startCommand; Pid = $null }
    }

    if ($App.type -eq "docker") {
        if (-not (Test-Path $App.path)) { return @{ Started = $false; Note = "path missing"; Pid = $null } }
        Push-Location $App.path
        docker compose up -d 2>&1 | Out-Null
        $code = $LASTEXITCODE
        Pop-Location
        return @{ Started = ($code -eq 0); Note = "docker compose exit=$code"; Pid = $null }
    }

    if ($App.startCommand -like "*.ps1") {
        & $App.startCommand 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        $r = Test-AppRunning -App $App
        return @{ Started = $r.Running; Note = "via ps1"; Pid = $r.Pid; Log = $outLog }
    }

    if ($App.type -eq "mcp" -and $App.startCommand -like "node*") {
        $node = (Get-Command node -ErrorAction SilentlyContinue).Source
        if (-not $node) { return @{ Started = $false; Note = "node missing"; Pid = $null } }
        if ($App.env) {
            foreach ($k in $App.env.PSObject.Properties.Name) {
                Set-Item -Path ("env:" + $k) -Value $App.env.$k
            }
        }
        $script = ($App.startCommand -replace "^node\s+", "")
        try {
            $proc = Start-Process -FilePath $node -ArgumentList $script -WorkingDirectory $App.path `
                -RedirectStandardOutput $outLog -RedirectStandardError $errLog -WindowStyle Hidden -PassThru
            Start-Sleep -Seconds 2
            return @{ Started = $true; Note = "background"; Pid = $proc.Id; Log = $outLog }
        } catch {
            return @{ Started = $false; Note = $_.Exception.Message; Pid = $null }
        }
    }

    # npm apps
    if (-not (Test-Path $App.path)) { return @{ Started = $false; Note = "path missing"; Pid = $null } }
    $npm = Join-Path (Split-Path (Get-Command node -ErrorAction SilentlyContinue).Source -Parent) "npm.cmd"
    if (-not (Test-Path $npm)) { $npm = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source }
    if (-not $npm) { return @{ Started = $false; Note = "npm missing"; Pid = $null } }

    if ($App.env) {
        foreach ($k in $App.env.PSObject.Properties.Name) {
            Set-Item -Path ("env:" + $k) -Value $App.env.$k
        }
    }

    $cmdParts = $App.startCommand -split "\s+", 2
    if ($cmdParts[0] -ne "npm") {
        return @{ Started = $false; Note = "unsupported startCommand"; Pid = $null }
    }
    $npmArgs = $cmdParts[1]
    try {
        $proc = Start-Process -FilePath $npm -ArgumentList $npmArgs -WorkingDirectory $App.path `
            -RedirectStandardOutput $outLog -RedirectStandardError $errLog -WindowStyle Hidden -PassThru
        return @{ Started = $true; Note = "background"; Pid = $proc.Id; Log = $outLog }
    } catch {
        return @{ Started = $false; Note = $_.Exception.Message; Pid = $null }
    }
}

function Stop-AppGraceful {
    param($App)
    if ($App.stopCommand -like "stdio:*" -or $App.stopCommand -like "note:*") {
        Write-Host ("[" + $App.id + "] " + $App.stopCommand + " — skipped")
        return @{ Stopped = $false; Note = $App.stopCommand }
    }

    if ($App.type -eq "docker") {
        if (-not (Test-Path $App.path)) { return @{ Stopped = $false; Note = "path missing" } }
        Push-Location $App.path
        docker compose down 2>&1 | Out-Null
        $code = $LASTEXITCODE
        Pop-Location
        return @{ Stopped = ($code -eq 0); Note = "docker compose down exit=$code" }
    }

    if ($App.stopCommand -like "port:*") {
        $port = [int]($App.stopCommand -replace "port:", "")
        $listenerPid = Get-ListenerPid $port
        if (-not $listenerPid) {
            return @{ Stopped = $true; Note = "port $port not in use" }
        }
        if (Test-IsProtectedPid -Pid $listenerPid) {
            Write-Warning ("[" + $App.id + "] PID $listenerPid is protected ($((Get-ProtectedProcessName -Pid $listenerPid))) — will NOT stop")
            return @{ Stopped = $false; Note = "protected process on port $port" }
        }
        try {
            Stop-Process -Id $listenerPid -ErrorAction Stop
            Start-Sleep -Milliseconds 500
            if (Test-PortListening $port) {
                Write-Warning ("[" + $App.id + "] Process $listenerPid did not release port $port — not force-killing")
                return @{ Stopped = $false; Note = "graceful stop incomplete" }
            }
            return @{ Stopped = $true; Note = "stopped pid=$listenerPid" }
        } catch {
            return @{ Stopped = $false; Note = $_.Exception.Message }
        }
    }

    return @{ Stopped = $false; Note = "no stop handler" }
}

function Invoke-DeviceStart {
    param([string]$Id, [bool]$SkipIfRunning = $true)

    if ($Id -eq "all") {
        $apps = Get-DeviceApps | Where-Object { $_.startCommand -notlike "note:*" }
        foreach ($a in $apps) {
            Invoke-DeviceStart -Id $a.id -SkipIfRunning $SkipIfRunning
        }
        # Also invoke MCP batch for stdio/ollama extras
        $mcpScript = Join-Path $Root "scripts\start-all-mcps.ps1"
        if (Test-Path $mcpScript) {
            Write-Host "[mcps] start-all-mcps.ps1"
            & $mcpScript -SkipGrok | Out-Null
        }
        Invoke-DeviceStatus | Out-Null
        return
    }

    $app = Get-AppById -Id $Id
    $running = Test-AppRunning -App $app
    if ($SkipIfRunning -and -not $ForceStart -and $running.Running) {
        Write-Host ("[" + $app.id + "] already running — skip (use -ForceStart to override)")
        return
    }

    Write-Host ("[" + $app.id + "] starting...")
    $result = Start-BackgroundApp -App $app
    Write-Host ("[" + $app.id + "] started=" + $result.Started + " pid=" + $result.Pid + " note=" + $result.Note)

    if ($OpenUI -and $app.url) {
        Start-Process $app.url | Out-Null
    }
}

function Invoke-DeviceStop {
    param([string]$Id)

    if ($Id -eq "all") {
        $apps = Get-DeviceApps | Where-Object { $_.stopCommand -notlike "stdio:*" -and $_.stopCommand -notlike "note:*" }
        # Stop npm/http first, docker last
        $ordered = @($apps | Where-Object { $_.type -ne "docker" }) + @($apps | Where-Object { $_.type -eq "docker" })
        foreach ($a in $ordered) {
            Invoke-DeviceStop -Id $a.id
        }
        Invoke-DeviceStatus | Out-Null
        return
    }

    $app = Get-AppById -Id $Id
    Write-Host ("[" + $app.id + "] stopping...")
    $result = Stop-AppGraceful -App $app
    Write-Host ("[" + $app.id + "] stopped=" + $result.Stopped + " note=" + $result.Note)
}

function Invoke-DeviceRestart {
    param([string]$Id)
    if (-not $Id -or $Id -eq "all") {
        Write-Error "restart requires a single app id"
        exit 1
    }
    Invoke-DeviceStop -Id $Id
    Start-Sleep -Seconds 2
    Invoke-DeviceStart -Id $Id -SkipIfRunning $false
    Invoke-DeviceStatus | Out-Null
}

function Invoke-DeviceOpen {
    param([string]$Id)
    if (-not $Id) {
        Write-Error "open requires an app id"
        exit 1
    }
    $app = Get-AppById -Id $Id
    if ($app.url) {
        Write-Host ("Opening " + $app.url)
        Start-Process $app.url | Out-Null
    }
    if ($app.workspaceFile -and (Test-Path $app.workspaceFile)) {
        if (Get-Command code -ErrorAction SilentlyContinue) {
            Write-Host ("Opening workspace " + $app.workspaceFile)
            Start-Process code -ArgumentList $app.workspaceFile | Out-Null
        }
    } elseif ($app.path -and $app.path -ne "system" -and (Test-Path $app.path)) {
        if (Get-Command code -ErrorAction SilentlyContinue) {
            Write-Host ("Opening folder " + $app.path)
            Start-Process code -ArgumentList $app.path | Out-Null
        }
    }
}

function Invoke-DeviceApps {
    $apps = Get-DeviceApps
    if ($Json) {
        $apps | Select-Object id, name, type, port, url | ConvertTo-Json -Depth 4
        return
    }
    Write-Host "=== Registered Apps ===" -ForegroundColor Cyan
    $apps | Select-Object id, name, type, port, url | Format-Table -AutoSize
}

switch ($Action) {
    "status"  { Invoke-DeviceStatus }
    "start"   { Invoke-DeviceStart -Id $(if ($Target) { $Target } else { "all" }) -SkipIfRunning $(-not $ForceStart) }
    "stop"    {
        if (-not $Target) { Write-Error "stop requires id or all"; exit 1 }
        Invoke-DeviceStop -Id $Target
    }
    "restart" { Invoke-DeviceRestart -Id $Target }
    "open"    { Invoke-DeviceOpen -Id $Target }
    "apps"    { Invoke-DeviceApps }
}
