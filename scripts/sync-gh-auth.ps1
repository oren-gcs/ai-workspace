# sync-gh-auth.ps1
param([switch]$Quiet,[switch]$PersistUserEnv)
$ErrorActionPreference = "Stop"
$env:GIT_TERMINAL_PROMPT = "0"
function Write-SyncMsg { param([string]$Message) if (-not $Quiet) { Write-Host $Message } }
function Get-GcmExecutable {
    $cmd = Get-Command git-credential-manager -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    foreach ($candidate in @("F:\DevSecOps\GIT\Git\mingw64\bin\git-credential-manager.exe","$env:ProgramFiles\Git\mingw64\bin\git-credential-manager.exe")) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}
$gcm = Get-GcmExecutable
if (-not $gcm) { Write-SyncMsg 'GCM missing'; exit 2 }
$credInput = @("protocol=https", "host=github.com", "") -join [char]10
$rawOut = ($credInput | & $gcm get 2>&1 | Out-String)
$token = ($rawOut -split "`r?`n" | Where-Object { $_ -match "^password=" } | ForEach-Object { ($_ -replace "^password=", "").Trim() } | Select-Object -First 1)
if (-not $token) { Write-SyncMsg 'GCM credential found: no'; exit 3 }
Write-SyncMsg 'GCM credential found: yes'
try { $login = (Invoke-RestMethod -Uri "https://api.github.com/user" -Headers @{ Authorization = "Bearer $token"; "User-Agent" = "sync-gh-auth"; Accept = "application/vnd.github+json" }).login } catch { Write-SyncMsg 'GitHub API rejected GCM token'; exit 4 }
$env:GH_TOKEN = $token
if ($PersistUserEnv) { [System.Environment]::SetEnvironmentVariable('GH_TOKEN', $token, 'User') }
gh auth setup-git 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Write-SyncMsg 'gh auth setup-git failed'; exit 5 }
gh auth status 2>&1 | Out-Null
Write-SyncMsg "gh synced for $login via GCM (process GH_TOKEN set)"
exit 0
