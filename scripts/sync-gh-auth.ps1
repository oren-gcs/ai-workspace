# sync-gh-auth.ps1 — Wire gh CLI from GH_TOKEN or Git Credential Manager (GCM).
# Does not print tokens. Logs outcome to ACTION-LOG on state change.
param(
    [string]$LogPath = "F:\ai-workspace\ACTION-LOG.md"
)

$ErrorActionPreference = "Continue"

function Test-GhAuthenticated {
    gh auth status 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Get-GhLogin {
    $login = gh api user -q .login 2>$null
    if ($LASTEXITCODE -eq 0) { return $login.Trim() }
    return $null
}

function Write-SyncLog {
    param([string]$Result, [string]$Detail)
    if (-not (Test-Path $LogPath)) { return }
    $date = Get-Date -Format "yyyy-MM-dd"
    $entry = @"

### $date — sync-gh-auth

| Field | Value |
|---|---|
| **Actor** | sync-gh-auth.ps1 |
| **Action** | Sync gh auth from GH_TOKEN or GCM |
| **Target** | Windows gh CLI |
| **Result** | $Result |
| **Next step** | $(if ($Result -eq "blocked") { "Set GH_TOKEN user env or run gh auth login interactively" } else { "none" }) |

"@
    $content = Get-Content -Raw -Path $LogPath
    $marker = "## Log entries"
    $idx = $content.IndexOf($marker)
    if ($idx -lt 0) { Add-Content -Path $LogPath -Value $entry; return }
    $insertAt = $idx + $marker.Length
    $newContent = $content.Substring(0, $insertAt) + "`n`n" + $entry.TrimEnd() + $content.Substring($insertAt)
    [System.IO.File]::WriteAllText($LogPath, $newContent)
}

# Already authenticated
if (Test-GhAuthenticated) {
    $login = Get-GhLogin
    Write-Host "gh already authenticated$(if ($login) { " as $login" })"
    exit 0
}

# Try GH_TOKEN from user environment
$userToken = [System.Environment]::GetEnvironmentVariable("GH_TOKEN", "User")
if ($userToken) {
    $env:GH_TOKEN = $userToken
    $login = gh api user -q .login 2>$null
    if ($LASTEXITCODE -eq 0) {
        gh auth setup-git 2>$null | Out-Null
        Write-Host "gh wired via GH_TOKEN user env as $login"
        Write-SyncLog -Result "success" -Detail "GH_TOKEN user env"
        exit 0
    }
    Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue
    Write-Host "GH_TOKEN set but invalid or expired"
}

# Try GCM via git credential fill
$gcmToken = $null
try {
    $credInput = "protocol=https`nhost=github.com`n`n"
    $credOutput = $credInput | git credential fill 2>$null
    if ($LASTEXITCODE -eq 0 -and $credOutput) {
        foreach ($line in ($credOutput -split "`n")) {
            if ($line -match '^password=(.+)$') {
                $gcmToken = $Matches[1]
                break
            }
        }
    }
} catch {
    Write-Host "GCM credential fill failed: $($_.Exception.Message)"
}

if ($gcmToken) {
    $gcmToken | gh auth login --with-token 2>$null
    if ($LASTEXITCODE -eq 0) {
        gh auth setup-git 2>$null | Out-Null
        $login = Get-GhLogin
        Write-Host "gh wired via GCM as $login"
        Write-SyncLog -Result "success" -Detail "GCM git credential"
        exit 0
    }
    Write-Host "GCM token found but gh auth login --with-token failed"
}

# Check GCM registry entry exists (informational)
$gcmEntry = cmdkey /list 2>$null | Select-String -Pattern "github|git:https://github.com"
if ($gcmEntry) {
    Write-Host "GCM GitHub entry detected but token not extractable — interactive gh auth login may be required"
} else {
    Write-Host "No GCM GitHub entry found"
}

Write-Host "sync-gh-auth: could not wire gh automatically"
Write-SyncLog -Result "blocked" -Detail "No valid GH_TOKEN or GCM token"
exit 1
