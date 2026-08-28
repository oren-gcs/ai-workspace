# git-background-worker.ps1 — Periodic fetch + auto-push for configured repos (non-blocking, per-repo timeout).
param(
    [string]$ConfigPath = "F:\ai-workspace\config\auto-push-repos.json",
    [int]$PerRepoTimeoutSec = 120,
    [switch]$SkipPush
)

$ErrorActionPreference = "Continue"
$logDir = Join-Path (Split-Path $PSScriptRoot -Parent) "logs\git-worker"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "worker-$stamp.log"
$mutexName = "Global\ai-workspace-git-background-worker"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
if (-not $mutex.WaitOne(0)) {
    "[$((Get-Date).ToString('o'))] Skip: another worker is running" | Add-Content $logFile
    exit 0
}

function Write-WorkerLog {
    param([string]$Line)
    $msg = "[$((Get-Date).ToString('o'))] $Line"
    Add-Content -Path $logFile -Value $msg
    if ($env:AI_WORKSPACE_GIT_WORKER_VERBOSE -eq "1") { Write-Host $msg }
}

try {
    $env:GIT_TERMINAL_PROMPT = "0"
    if (-not (Test-Path $ConfigPath)) {
        Write-WorkerLog "Config missing: $ConfigPath"
        exit 1
    }
    $repos = @(Get-Content -Raw $ConfigPath | ConvertFrom-Json).repos
    $cleanupScript = Join-Path $PSScriptRoot "cleanup-stuck-git-bash.ps1"
    if (Test-Path $cleanupScript) {
        $cleanupLine = (& $cleanupScript 2>&1 | Out-String).Trim() -replace "`r?`n", " "
        if ($cleanupLine) { Write-WorkerLog "bash-cleanup: $cleanupLine" }
    }
    Write-WorkerLog "Start ($($repos.Count) repos, timeout ${PerRepoTimeoutSec}s)"

    $sync = Join-Path $PSScriptRoot "sync-gh-auth.ps1"
    if ((Test-Path $sync) -and -not $env:GH_TOKEN) {
        & $sync -Quiet 2>$null
    }

    foreach ($r in $repos) {
        $path = ($r.path -replace '/', '\')
        $name = Split-Path $path -Leaf
        if (-not (Test-Path (Join-Path $path ".git"))) {
            Write-WorkerLog "$name skip: not a git repo"
            continue
        }
        $job = Start-Job -ScriptBlock {
            param($RepoPath, $DoPush, $ScriptRoot)
            $env:GIT_TERMINAL_PROMPT = "0"
            Set-Location $RepoPath
            git fetch origin --prune 2>&1 | Out-Null
            if ($DoPush) {
                & (Join-Path $ScriptRoot "auto-push.ps1") -OnlyPath $RepoPath 2>&1 | Out-Null
            }
        } -ArgumentList $path, (-not $SkipPush), $PSScriptRoot
        $done = Wait-Job $job -Timeout $PerRepoTimeoutSec
        if (-not $done) {
            Stop-Job $job -Force | Out-Null
            Remove-Job $job -Force | Out-Null
            Write-WorkerLog "$name timeout after ${PerRepoTimeoutSec}s"
            continue
        }
        Receive-Job $job | Out-Null
        Remove-Job $job -Force | Out-Null
        Write-WorkerLog "$name ok"
    }
    Write-WorkerLog "Done"
} finally {
    $mutex.ReleaseMutex() | Out-Null
    $mutex.Dispose()
}
