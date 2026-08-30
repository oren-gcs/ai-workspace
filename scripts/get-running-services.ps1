# get-running-services.ps1 — Probe local ports/processes; update config/running-services.json
param(
    [switch]$Quiet,
    [switch]$JsonOnly
)

$ErrorActionPreference = "Continue"
$Root = "F:\ai-workspace"
$OutFile = Join-Path $Root "config\running-services.json"
$AppsFile = Join-Path $Root "config\device-apps.json"
$Now = (Get-Date).ToString("o")
$ProbePorts = @(3000, 5173, 8080, 8088, 3847, 11434, 11435, 5432, 8000, 3001, 3002, 3003, 3004, 3007)

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

function Get-ListenerPid {
    param([int]$Port, [string]$Address = "127.0.0.1")
    try {
        $conns = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Where-Object { $_.LocalPort -eq $Port -and ($_.LocalAddress -eq $Address -or $_.LocalAddress -eq "0.0.0.0" -or $_.LocalAddress -eq "::") }
        if ($conns) { return [int]($conns | Select-Object -First 1 -ExpandProperty OwningProcess) }
    } catch {}
    $line = netstat -ano | Select-String -Pattern (":" + $Port + "\s+.*LISTENING")
    if ($line) {
        $parts = ($line.ToString().Trim() -split "\s+")
        if ($parts.Length -ge 5) { return [int]$parts[-1] }
    }
    return $null
}

function Test-HttpHealth {
    param([string]$Url, [int]$TimeoutSec = 2)
    if (-not $Url) { return $false }
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500)
    } catch { return $false }
}

function Get-ProcessNameForPid {
    param([Nullable[int]]$ListenerPid)
    if (-not $ListenerPid) { return $null }
    try { return (Get-Process -Id $ListenerPid -ErrorAction Stop).ProcessName } catch { return $null }
}

function Get-AllNodeProcesses {
    if ($script:CachedNodeProcesses) { return $script:CachedNodeProcesses }
    try {
        $script:CachedNodeProcesses = @(Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue)
    } catch { $script:CachedNodeProcesses = @() }
    return $script:CachedNodeProcesses
}

function Get-DockerPsLines {
    if ($null -ne $script:CachedDockerLines) { return $script:CachedDockerLines }
    $script:CachedDockerLines = @()
    try {
        docker info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $script:CachedDockerLines = @(docker ps --format "{{.Names}}|{{.Status}}" 2>$null)
        }
    } catch {}
    return $script:CachedDockerLines
}

function Get-DockerContainerStatus {
    param([string[]]$NamePatterns)
    $result = @{ Running = $false; Names = @(); State = "unknown" }
    $lines = Get-DockerPsLines
    if ($lines.Count -eq 0) { $result.State = "docker-down"; return $result }
    foreach ($line in $lines) {
        if (-not $line) { continue }
        $parts = $line -split "\|", 2
        $name = $parts[0]
        $status = if ($parts.Length -gt 1) { $parts[1] } else { "" }
        foreach ($pat in $NamePatterns) {
            if ($name -match $pat) {
                $result.Names += $name
                if ($status -match "^Up") { $result.Running = $true; $result.State = "up" }
            }
        }
    }
    if ($result.Names.Count -gt 0 -and -not $result.Running) { $result.State = "down" }
    return $result
}

function Get-NodePidForProject {
    param([string]$ProjectPath)
    if (-not $ProjectPath -or $ProjectPath -eq "system") { return $null }
    $norm = $ProjectPath.TrimEnd('\')
    foreach ($p in (Get-AllNodeProcesses)) {
        if ($p.CommandLine -and ($p.CommandLine -like ("*" + $norm + "*"))) {
            return [int]$p.ProcessId
        }
    }
    return $null
}

function Test-BrainSmoke {
    $smoke = "C:\Users\oren\.claude\brain\mcp\smoke.mjs"
    if (-not (Test-Path $smoke)) { return $false }
    $job = Start-Job -ScriptBlock { param($s) & node $s 2>&1 } -ArgumentList $smoke
    $done = Wait-Job $job -Timeout 5
    if (-not $done) { Stop-Job $job -Force; Remove-Job $job -Force; return $false }
    $lines = @(Receive-Job $job)
    Remove-Job $job -Force
    $text = ($lines | ForEach-Object { "$_" }) -join [Environment]::NewLine
    return ($text -match "INIT: ok") -and ($text -match "STATUS: ok")
}

function New-ServiceEntry {
    param($Definition, [string]$CheckedAt)

    $listening = $false
    $healthOk = $false
    $status = "stopped"
    $listenerPid = $null
    $dockerNote = $null

    if ($Definition.id -eq "brain-mcp" -and $Definition.verify) {
        $smoke = $Definition.verify -replace "^node\s+", ""
        if (Test-Path $smoke) {
            $lines = @(& node $smoke 2>&1)
            $text = ($lines | ForEach-Object { "$_" }) -join [Environment]::NewLine
            $healthOk = ($text -match "INIT: ok") -and ($text -match "STATUS: ok")
            $status = if ($healthOk) { "running" } else { "stopped" }
        }
    } elseif ($Definition.port) {
        $listening = Test-PortListening -Port $Definition.port
        $listenerPid = if ($listening) { Get-ListenerPid -Port $Definition.port } else { $null }
        if (-not $listenerPid -and $Definition.projectPath) {
            $listenerPid = Get-NodePidForProject -ProjectPath $Definition.projectPath
        }
        if ($Definition.kind -eq "docker" -and $Definition.dockerPatterns) {
            $dk = Get-DockerContainerStatus -NamePatterns $Definition.dockerPatterns
            $dockerNote = if ($dk.Names.Count -gt 0) { ($dk.Names -join ", ") + " [" + $dk.State + "]" } else { "no matching container" }
            if ($dk.Running) { $status = "running"; $healthOk = $true }
        }
        if ($listening) {
            if ($Definition.healthUrl) {
                $healthOk = Test-HttpHealth -Url $Definition.healthUrl
                if ($status -ne "running") { $status = if ($healthOk) { "running" } else { "listening" } }
            } else {
                $healthOk = $true
                if ($status -ne "running") { $status = "running" }
            }
        }
    }

    $svc = [ordered]@{
        id          = $Definition.id
        port        = $Definition.port
        pid         = $listenerPid
        url         = $Definition.url
        status      = $status
        healthOk    = $healthOk
        listening   = $listening
        kind        = $Definition.kind
        process     = (Get-ProcessNameForPid -ListenerPid $listenerPid)
        docker      = $dockerNote
        projectPath = $Definition.projectPath
        parallel    = $Definition.parallel
        lastCheck   = $CheckedAt
    }

    $row = [PSCustomObject]@{
        Id       = $Definition.id
        Status   = $status
        Port     = if ($Definition.port) { $Definition.port } else { "-" }
        PID      = if ($listenerPid) { $listenerPid } else { "-" }
        Health   = if ($Definition.healthUrl) { if ($healthOk) { "ok" } else { "no" } } elseif ($listening) { "ok" } else { "-" }
        URL      = if ($Definition.url) { $Definition.url } else { "-" }
        Parallel = if ($Definition.parallel) { "yes" } else { "no" }
    }

    return @{ Service = $svc; Row = $row }
}

$ExtraServices = @(
    @{ id = "doc-power-grafana"; port = 3001; url = "http://localhost:3001"; healthUrl = "http://localhost:3001"; kind = "docker"; dockerPatterns = @("grafana"); projectPath = "F:\DevSecOps\projects\doc-power-local-k8s"; parallel = $true },
    @{ id = "doc-power-api-gateway"; port = 8000; url = "http://localhost:8000"; healthUrl = "http://localhost:8000/docs"; kind = "docker"; dockerPatterns = @("api-gateway"); projectPath = "F:\DevSecOps\projects\doc-power-local-k8s"; parallel = $true },
    @{ id = "doc-power-postgres"; port = 5432; url = "postgresql://127.0.0.1:5432"; healthUrl = $null; kind = "docker"; dockerPatterns = @("postgres"); projectPath = "F:\DevSecOps\projects\doc-power-local-k8s"; parallel = $true },
    @{ id = "doc-power-cadvisor"; port = 8080; url = "http://localhost:8080"; healthUrl = "http://localhost:8080"; kind = "docker"; dockerPatterns = @("cadvisor"); projectPath = "F:\DevSecOps\projects\doc-power-local-k8s"; parallel = $true },
    @{ id = "doc-power-admin"; port = 8088; url = "http://localhost:8088"; healthUrl = "http://localhost:8088"; kind = "docker"; dockerPatterns = @("admin"); projectPath = "F:\DevSecOps\projects\doc-power-local-k8s"; parallel = $true },
    @{ id = "vite-dev"; port = 5173; url = "http://localhost:5173"; healthUrl = "http://localhost:5173"; kind = "node"; dockerPatterns = @(); projectPath = $null; parallel = $true }
)

$IdAliases = @{
    "grok-bot"     = "grok-social-bot"
    "gcs-tech"     = "GCS-tech"
    "study-portal" = "my_study_portal"
    "cordev"       = "Gcs-CorDev-insights"
    "ollama"       = "ollama-daemon"
}

$services = @()
$tableRows = @()

if (Test-Path $AppsFile) {
    $appsCfg = Get-Content -Raw $AppsFile | ConvertFrom-Json
    foreach ($app in $appsCfg.apps) {
        $svcId = if ($IdAliases.ContainsKey($app.id)) { $IdAliases[$app.id] } else { $app.id }
        $kind = switch ($app.type) { "docker" { "docker" } "stdio" { "stdio" } default { "node" } }
        $dockerPatterns = @()
        if ($kind -eq "docker") { $dockerPatterns = @($app.id, ($app.id -replace "-", ".*")) }
        $def = @{
            id = $svcId
            port = $app.port
            url = $app.url
            healthUrl = $app.healthUrl
            kind = $kind
            dockerPatterns = $dockerPatterns
            projectPath = $app.path
            parallel = ($null -ne $app.port)
            verify = $app.verify
        }
        $entry = New-ServiceEntry -Definition $def -CheckedAt $Now
        $services += $entry.Service
        $tableRows += $entry.Row
    }
}

foreach ($def in $ExtraServices) {
    if (@($services | Where-Object { $_.id -eq $def.id }).Count -gt 0) { continue }
    $entry = New-ServiceEntry -Definition $def -CheckedAt $Now
    $services += $entry.Service
    $tableRows += $entry.Row
}

foreach ($port in $ProbePorts) {
    if (@($services | Where-Object { $_.port -eq $port }).Count -gt 0) { continue }
    if (-not (Test-PortListening -Port $port)) { continue }
    $listenerPid = Get-ListenerPid -Port $port
    $services += [ordered]@{
        id = "unknown-$port"
        port = $port
        pid = $listenerPid
        url = "http://localhost:$port"
        status = "listening"
        healthOk = $false
        listening = $true
        kind = "unknown"
        process = (Get-ProcessNameForPid -ListenerPid $listenerPid)
        docker = $null
        projectPath = $null
        parallel = $false
        lastCheck = $Now
    }
}

$payload = [ordered]@{
    version    = "1.0.0"
    updatedAt  = $Now
    probePorts = $ProbePorts
    services   = @($services)
}

$configDir = Split-Path $OutFile -Parent
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
$payload | ConvertTo-Json -Depth 8 | Set-Content -Path $OutFile -Encoding UTF8

if ($JsonOnly) {
    $payload | ConvertTo-Json -Depth 8 -Compress
} elseif (-not $Quiet) {
    Write-Host ("[get-running-services] updated " + $OutFile)
    $tableRows | Format-Table -AutoSize
}

$global:GetRunningServices = $services
exit 0
