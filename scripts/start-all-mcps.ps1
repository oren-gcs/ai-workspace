# start-all-mcps.ps1 — Start HTTP/local MCP-adjacent services; verify stdio MCP readiness.
param(
    [switch]$SkipGrok,
    [switch]$StartOllamaMcp,
    [switch]$SkipIfRunning = $true,
    [switch]$ForceRestart,
    [int]$WaitSeconds = 8
)
$ErrorActionPreference = "Continue"
$Root = "F:\ai-workspace"
$LogDir = Join-Path $Root "logs"
$Day = Get-Date -Format "yyyy-MM-dd"
$McpLog = Join-Path $LogDir ("mcps-" + $Day + ".md")
$Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

$ProbeScript = Join-Path $Root "scripts\get-running-services.ps1"
if (Test-Path $ProbeScript) { & $ProbeScript -Quiet 2>&1 | Out-Null }

function Write-McpLog([string]$Line) {
  if (-not (Test-Path $McpLog)) {
    @("# MCP services — $Day", "", "| Time | Event |", "|------|-------|") | Set-Content -Path $McpLog -Encoding UTF8
  }
  Add-Content -Path $McpLog -Value ("| " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " | " + $Line) -Encoding UTF8
}

function Test-PortListening([int]$Port, [string]$Address = "127.0.0.1") {
  try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $iar = $tcp.BeginConnect($Address, $Port, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne(500)
    if ($ok -and $tcp.Connected) { $tcp.Close(); return $true }
    $tcp.Close()
  } catch {}
  return $false
}

function Test-HttpOk([string]$Url, [int]$TimeoutSec = 5) {
  try {
    $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
    return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500)
  } catch { return $false }
}

function Get-ListenerPid([int]$Port, [string]$Address = "127.0.0.1") {
  try {
    $conns = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
      Where-Object { $_.LocalPort -eq $Port -and ($_.LocalAddress -eq $Address -or $_.LocalAddress -eq "0.0.0.0") }
    if ($conns) { return [int]($conns | Select-Object -First 1 -ExpandProperty OwningProcess) }
  } catch {}
  $line = netstat -ano | Select-String -Pattern ("TCP\s+" + [regex]::Escape($Address) + ":" + $Port + "\s")
  if (-not $line) { return $null }
  $parts = ($line.ToString().Trim() -split "\s+")
  if ($parts.Length -ge 5) { return [int]$parts[-1] }
  return $null
}

function Get-ServiceFromRegistry([string]$Id) {
  $regPath = Join-Path $Root "config\running-services.json"
  if (-not (Test-Path $regPath)) { return $null }
  $data = Get-Content -Raw $regPath | ConvertFrom-Json
  return $data.services | Where-Object { $_.id -eq $Id } | Select-Object -First 1
}

function Test-ServiceHealthy {
  param([string]$Id, [int]$Port, [string]$HealthUrl)
  $reg = Get-ServiceFromRegistry -Id $Id
  if ($reg -and $reg.status -eq "running" -and $reg.healthOk) { return $true }
  if (-not (Test-PortListening $Port)) { return $false }
  if ($HealthUrl) { return (Test-HttpOk $HealthUrl) }
  return $true
}

function Stop-ListenerOnPort {
  param([int]$Port)
  $listenerPid = Get-ListenerPid -Port $Port
  if ($listenerPid) {
    Write-McpLog ("ForceRestart: stopping pid $listenerPid on port $Port")
    Stop-Process -Id $listenerPid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
  }
}

function Invoke-BrainSmoke() {
  $smokePath = "C:\Users\oren\.claude\brain\mcp\smoke.mjs"
  if (-not (Test-Path $smokePath)) { return $false }
  $lines = @(& node $smokePath 2>&1)
  $text = ($lines | ForEach-Object { "$_" }) -join [Environment]::NewLine
  return ($text -match "INIT: ok") -and ($text -match "STATUS: ok")
}

function Start-DetachedNode([string]$Name, [string]$WorkDir, [string]$ScriptPath, [hashtable]$Env = @{}) {
  $node = (Get-Command node -ErrorAction SilentlyContinue).Source
  if (-not $node) { return @{ Started = $false; Note = "node missing"; Pid = $null; Log = $null } }
  foreach ($k in $Env.Keys) { Set-Item -Path ("env:" + $k) -Value $Env[$k] }
  $out = Join-Path $LogDir ($Name + "-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
  try {
    $proc = Start-Process -FilePath $node -ArgumentList $ScriptPath -WorkingDirectory $WorkDir -RedirectStandardOutput $out -RedirectStandardError $out -WindowStyle Hidden -PassThru
    return @{ Started = $true; Note = "background"; Pid = $proc.Id; Log = $out }
  } catch {
    return @{ Started = $false; Note = $_.Exception.Message; Pid = $null; Log = $out }
  }
}

Write-Host ("[start-all-mcps] " + $Stamp)
Write-McpLog "run started (SkipIfRunning=$SkipIfRunning ForceRestart=$ForceRestart)"

$results = @()

$ollamaOk = Test-ServiceHealthy -Id "ollama-daemon" -Port 11434 -HealthUrl "http://127.0.0.1:11434/api/tags"
$results += [PSCustomObject]@{ Name="ollama-daemon"; Started=$ollamaOk; Port=11434; Transport="http-prereq"; CursorConfig="n/a"; Verify="Invoke-WebRequest http://127.0.0.1:11434/api/tags"; Note=$(if($ollamaOk){"already running"}else{"start Ollama manually"}) }

$ollamaMcpDir = "C:\Users\oren\ollama-mcp"
$ollamaMcpPort = 11435
$ollamaMcpHealthy = Test-ServiceHealthy -Id "ollama-mcp" -Port $ollamaMcpPort -HealthUrl "http://127.0.0.1:11435/"
if ($ollamaMcpHealthy -and $SkipIfRunning -and -not $ForceRestart) {
  Write-Host "[ollama-mcp] already running on :$ollamaMcpPort — skip"
  Write-McpLog "ollama-mcp: already running — skip"
} elseif ((Test-PortListening $ollamaMcpPort) -and -not $ForceRestart) {
  $wrongPid = Get-ListenerPid $ollamaMcpPort
  Write-Host "[ollama-mcp] WARN port $ollamaMcpPort in use by pid $wrongPid (not healthy) — skip (use -ForceRestart)"
  Write-McpLog "ollama-mcp: port conflict pid=$wrongPid"
} else {
  if ($ForceRestart -and (Test-PortListening $ollamaMcpPort)) { Stop-ListenerOnPort -Port $ollamaMcpPort }
  if (Test-Path (Join-Path $ollamaMcpDir "server.js")) {
    $start = Start-DetachedNode -Name "ollama-mcp" -WorkDir $ollamaMcpDir -ScriptPath "server.js" -Env @{ MCP_PORT="$ollamaMcpPort"; MCP_BIND="127.0.0.1"; OLLAMA_HOST="http://127.0.0.1:11434" }
    Write-McpLog ("ollama-mcp start pid=" + $start.Pid)
    Start-Sleep -Seconds 2
  }
}
$ollamaMcpOk = Test-PortListening $ollamaMcpPort
$results += [PSCustomObject]@{ Name="ollama-mcp"; Started=$ollamaMcpOk; Port=$ollamaMcpPort; Transport="http"; CursorConfig="F:\ai-workspace\.cursor\mcp.json"; Verify="Invoke-WebRequest http://127.0.0.1:11435/"; Note=("pid=" + (Get-ListenerPid $ollamaMcpPort)) }

$brainOk = Invoke-BrainSmoke
$results += [PSCustomObject]@{ Name="brain-mcp"; Started=$brainOk; Port=$null; Transport="stdio"; CursorConfig="F:\ai-workspace\.cursor\mcp.json"; Verify="node C:\Users\oren\.claude\brain\mcp\smoke.mjs"; Note=$(if($brainOk){"stdio-ready"}else{"smoke failed"}) }

$dpOk = (Test-Path "F:\DevSecOps\projects\doc-power-local-k8s\mcp-ollama-agents\server.py") -and (Get-Command python -ErrorAction SilentlyContinue) -and $ollamaOk
$results += [PSCustomObject]@{ Name="doc-power-ollama-agents"; Started=$dpOk; Port=$null; Transport="stdio"; CursorConfig="F:\DevSecOps\projects\doc-power-local-k8s\.mcp.json"; Verify="python ...\smoke_test.py"; Note="stdio only" }

$dockerOk = $false
try { docker info 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { $dockerOk = $true } } catch {}
$results += [PSCustomObject]@{ Name="MCP_DOCKER"; Started=$dockerOk; Port=$null; Transport="stdio"; CursorConfig="Claude Desktop"; Verify="docker info"; Note=$(if($dockerOk){"IDE-spawn docker mcp gateway run"}else{"Docker daemon down"}) }

$grokPort = 3847
$grokHealthy = Test-ServiceHealthy -Id "grok-social-bot" -Port $grokPort -HealthUrl "http://127.0.0.1:3847"
if (-not $SkipGrok) {
  if ($grokHealthy -and $SkipIfRunning -and -not $ForceRestart) {
    Write-Host "[grok-social-bot] already running on :$grokPort — skip"
    Write-McpLog "grok-social-bot: already running — skip"
  } elseif ((Test-PortListening $grokPort) -and -not $ForceRestart) {
    $wrongPid = Get-ListenerPid $grokPort
    Write-Host "[grok-social-bot] WARN port $grokPort in use by pid $wrongPid — skip (use -ForceRestart)"
    Write-McpLog "grok-social-bot: port conflict pid=$wrongPid"
  } else {
    if ($ForceRestart -and (Test-PortListening $grokPort)) { Stop-ListenerOnPort -Port $grokPort }
    $grokScript = Join-Path $Root "scripts\start-grok-bot-session.ps1"
    if (Test-Path $grokScript) { & $grokScript 2>&1 | Out-Null; Start-Sleep -Seconds 3 }
  }
}
$grokListen = Test-PortListening $grokPort
$results += [PSCustomObject]@{ Name="grok-social-bot"; Started=$grokListen; Port=$grokPort; Transport="http-webhook"; CursorConfig="n/a"; Verify="Test-NetConnection 127.0.0.1 -Port 3847"; Note=("pid=" + (Get-ListenerPid $grokPort)) }

foreach ($npxName in @("memory","filesystem","sequential-thinking")) {
  $results += [PSCustomObject]@{ Name=("mcp-" + $npxName); Started=[bool](Get-Command npx -ErrorAction SilentlyContinue); Port=$null; Transport="stdio"; CursorConfig="F:\ai-workspace\.cursor\mcp.json"; Verify=("npx -y @modelcontextprotocol/server-" + $npxName); Note="IDE-spawned" }
}

Start-Sleep -Seconds $WaitSeconds

if (Test-Path $ProbeScript) { & $ProbeScript -Quiet 2>&1 | Out-Null }

$ollamaRow = $results | Where-Object Name -eq "ollama-mcp" | Select-Object -First 1
if ($ollamaRow) {
  $ollamaRow.Started = Test-HttpOk "http://127.0.0.1:11435/" 15
  $ollamaRow.Note = "pid=" + (Get-ListenerPid 11435)
}
$brainRow = $results | Where-Object Name -eq "brain-mcp" | Select-Object -First 1
if ($brainRow) {
  $brainRow.Started = Invoke-BrainSmoke
  $brainRow.Note = if ($brainRow.Started) { "stdio-ready" } else { "smoke failed" }
}

$results | Format-Table -AutoSize
Write-McpLog ("summary: " + (($results | ForEach-Object { $_.Name + "=" + $_.Started }) -join ", "))
$global:StartAllMcpsResults = $results
return $results
