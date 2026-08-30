# start-all-local.ps1
param([switch]$SkipDocker,[switch]$SkipOpen,[int]$WaitSeconds=30)
$ErrorActionPreference = "Continue"
$Root = "F:\ai-workspace"
$LogDir = Join-Path $Root "logs\local-services"
$RunLog = Join-Path $Root ("logs\services-{0}-run.md" -f (Get-Date -Format "yyyy-MM-dd"))
$Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
function Write-RunLogLine([string]$Line) { Add-Content -Path $RunLog -Value $Line -Encoding UTF8 }
function Test-PortListening([int]$Port,[string]$Address="127.0.0.1") {
  try { $tcp = New-Object System.Net.Sockets.TcpClient; $iar = $tcp.BeginConnect($Address,$Port,$null,$null)
    $ok = $iar.AsyncWaitHandle.WaitOne(500); if ($ok -and $tcp.Connected) { $tcp.Close(); return $true }; $tcp.Close() } catch {}
  return $false
}
function Test-HttpOk([string]$Url,[int]$TimeoutSec=3) {
  try { $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop; return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) } catch { return $false }
}
function Start-BackgroundProcess {
  param([string]$Name,[string]$WorkDir,[string]$FilePath,[string]$ArgumentString,[hashtable]$Environment=@{})
  $safeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $outLog = Join-Path $LogDir ($Name + "-" + $safeStamp + ".log")
  $errLog = Join-Path $LogDir ($Name + "-" + $safeStamp + ".err.log")
  if (-not (Test-Path $WorkDir)) { return [PSCustomObject]@{Name=$Name;Started=$false;Note="path missing";Pid=$null;Log=$outLog} }
  foreach ($k in $Environment.Keys) { Set-Item -Path ("env:" + $k) -Value $Environment[$k] }
  try {
    $proc = Start-Process -FilePath $FilePath -ArgumentList $ArgumentString -WorkingDirectory $WorkDir -RedirectStandardOutput $outLog -RedirectStandardError $errLog -WindowStyle Hidden -PassThru
    return [PSCustomObject]@{Name=$Name;Started=($null -ne $proc);Note="background";Pid=$proc.Id;Log=$outLog}
  } catch { return [PSCustomObject]@{Name=$Name;Started=$false;Note=$_.Exception.Message;Pid=$null;Log=$outLog} }
}
function Start-NpmScript {
  param([string]$Name,[string]$WorkDir,[string]$Script="dev",[string[]]$ExtraArgs=@(),[hashtable]$Environment=@{})
  $npm = Join-Path (Split-Path (Get-Command node -ErrorAction SilentlyContinue).Source -Parent) "npm.cmd"; if (-not (Test-Path $npm)) { $npm = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source }
  if (-not $npm) { return [PSCustomObject]@{Name=$Name;Started=$false;Note="npm missing";Pid=$null} }
  $pj = Join-Path $WorkDir "package.json"
  if (-not (Test-Path $pj)) { return [PSCustomObject]@{Name=$Name;Started=$false;Note="no package.json";Pid=$null} }
  $j = Get-Content $pj -Raw | ConvertFrom-Json
  if (-not ($j.scripts.PSObject.Properties.Name -contains $Script)) { return [PSCustomObject]@{Name=$Name;Started=$false;Note=("no script " + $Script);Pid=$null} }
  $npmArgs = @("run",$Script) + $ExtraArgs
  return Start-BackgroundProcess -Name $Name -WorkDir $WorkDir -FilePath $npm -ArgumentString ($npmArgs -join " ") -Environment $Environment
}
Write-Host ("[start-all-local] " + $Stamp)
Write-RunLogLine ("# Local services run — " + $Stamp)
Write-RunLogLine ""
if (Test-Path ($Root + "\scripts\device-access-check.ps1")) { & ($Root + "\scripts\device-access-check.ps1") 2>&1 | Out-Null }
$mcpScript = Join-Path $Root "scripts\start-all-mcps.ps1"
if (Test-Path $mcpScript) {
  Write-Host "[mcps] start-all-mcps.ps1"
  & $mcpScript -SkipGrok | Out-Null
  Write-RunLogLine "mcps: start-all-mcps invoked (SkipGrok; grok started with other apps)"
}
if (-not $SkipDocker) {
  $dp = "F:\DevSecOps\projects\doc-power-local-k8s"
  if (Test-Path (Join-Path $dp "docker-compose.yml")) {
    Write-Host "[doc-power] docker compose up -d"
    Push-Location $dp; docker compose up -d 2>&1 | Out-Null; Pop-Location
    Write-RunLogLine ("doc-power docker compose exit=" + $LASTEXITCODE)
  }
}
$starts = @(
  @{Name="my_study_portal";Dir="F:\DevSecOps\projects\my_study_portal";Script="dev";Env=@{PORT="3007"};Url="http://localhost:3007";Port=3007},
  @{Name="fun4kids";Dir="F:\fun4kids";Script="dev";Env=@{PORT="3002"};Url="http://localhost:3002";Port=3002},
  @{Name="GCS-tech";Dir="F:\DevSecOps\projects\GCS-tech";Script="dev";Env=@{};Extra=@("--","--port","3003","--host","127.0.0.1");Url="http://localhost:3003";Port=3003},
  @{Name="Gcs-CorDev-insights";Dir="F:\DevSecOps\projects\Gcs-CorDev\app-code\insights";Script="start";Env=@{PORT="3004";BROWSER="none"};Url="http://localhost:3004";Port=3004},
  @{Name="grok-social-bot";Dir="F:\ai-workspace\projects\grok-social-bot\local";Script="dry-run";Env=@{BOT_PORT="3847"};Url="http://127.0.0.1:3847";Port=3847}
)
$startNotes = @()
foreach ($s in $starts) {
  if ($s.Port -and (Test-PortListening $s.Port)) {
    Write-Host ("[" + $s.Name + "] port " + $s.Port + " in use — skip")
    $startNotes += ($s.Name + ": skipped (port)")
    continue
  }
  $extra = @(); if ($s.Extra) { $extra = $s.Extra }
  $r = Start-NpmScript -Name $s.Name -WorkDir $s.Dir -Script $s.Script -ExtraArgs $extra -Environment $s.Env
  Write-Host ("[" + $s.Name + "] started=" + $r.Started + " pid=" + $r.Pid)
  $startNotes += ($s.Name + ": started=" + $r.Started + " pid=" + $r.Pid + " log=" + $r.Log)
}
Write-RunLogLine "mcp-ollama-agents: stdio-only (see start-all-mcps.ps1)"
Write-RunLogLine "cka-ai-bootcamp: skipped (bridge auth)"
Write-RunLogLine "brain-mcp: Claude/Cursor stdio only"
Write-Host ("Waiting " + $WaitSeconds + " s...")
Start-Sleep -Seconds $WaitSeconds
$verify = @(
  @{Project="doc-power-local-k8s";Url="http://localhost:3000";Port=3000},
  @{Project="doc-power-grafana";Url="http://localhost:3001";Port=3001},
  @{Project="doc-power-api-gateway";Url="http://localhost:8000/docs";Port=8000},
  @{Project="my_study_portal";Url="http://localhost:3007";Port=3007},
  @{Project="fun4kids";Url="http://localhost:3002";Port=3002},
  @{Project="GCS-tech";Url="http://localhost:3003";Port=3003},
  @{Project="Gcs-CorDev-insights";Url="http://localhost:3004";Port=3004},
  @{Project="grok-social-bot";Url="http://127.0.0.1:3847";Port=3847}
)
$statusRows = @()
foreach ($v in $verify) {
  $listening = Test-PortListening $v.Port
  $http = if ($listening) { Test-HttpOk $v.Url } else { $false }
  $running = $listening -or $http
  $statusRows += [PSCustomObject]@{Project=$v.Project;Running=$running;PortListening=$listening;HttpOk=$http;Url=$v.Url}
  Write-RunLogLine ($v.Project + " running=" + $running + " url=" + $v.Url + " listen=" + $listening + " http=" + $http)
}
$wsDir = Join-Path $Root "workspaces"
if (-not (Test-Path $wsDir)) { New-Item -ItemType Directory -Path $wsDir -Force | Out-Null }
$masterWs = Join-Path $wsDir "master.code-workspace"
if (-not (Test-Path $masterWs)) {
  $wsObj = @{ folders = @(
    @{path="F:/ai-workspace";name="ai-workspace"},
    @{path="F:/DevSecOps/projects/doc-power-local-k8s";name="doc-power-local-k8s"},
    @{path="F:/fun4kids";name="fun4kids"},
    @{path="F:/DevSecOps/projects/GCS-tech";name="GCS-tech"},
    @{path="F:/DevSecOps/projects/Gcs-CorDev";name="Gcs-CorDev"},
    @{path="F:/DevSecOps/projects/my_study_portal";name="my_study_portal"},
    @{path="F:/DevSecOps/projects/cka-ai-bootcamp";name="cka-ai-bootcamp"},
    @{path="F:/ai-workspace/projects/grok-social-bot";name="grok-social-bot"}
  ); settings = @{} }
  $wsObj | ConvertTo-Json -Depth 6 | Set-Content $masterWs -Encoding UTF8
}
$codeOpened = @()
if (-not $SkipOpen) {
  if (Get-Command code -ErrorAction SilentlyContinue) {
    Start-Process code -ArgumentList $masterWs | Out-Null
    $codeOpened += "master.code-workspace"
    Start-Process code -ArgumentList @("--new-window","F:\ai-workspace\projects\grok-social-bot") | Out-Null
    $codeOpened += "grok-social-bot"
    foreach ($p in @("F:\ai-workspace\projects\doc-power","F:\ai-workspace\projects\fun4kids","F:\ai-workspace\projects\gcs-tech","F:\ai-workspace\projects\my-study-portal")) {
      if (Test-Path $p) { Start-Process code -ArgumentList $p | Out-Null; $codeOpened += (Split-Path $p -Leaf) }
    }
  }
  foreach ($v in $statusRows) { if ($v.Running -and $v.Url) { Start-Process $v.Url | Out-Null } }
}
Write-RunLogLine ("VS Code: " + ($codeOpened -join ", "))
Write-RunLogLine "Re-run: F:\ai-workspace\scripts\start-all-local.ps1"
$global:StartAllLocalStatus = $statusRows
$global:StartAllLocalCodeOpened = $codeOpened
$statusRows | Format-Table -AutoSize
Write-Host ("Log: " + $RunLog)



