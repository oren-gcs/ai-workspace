# auto-push.ps1 — Push configured repos when ahead of remote and GitHub auth is available.
# Never force-pushes. Logs to F:\ai-workspace\ACTION-LOG.md
param(
    [string]$ConfigPath = "F:\ai-workspace\config\auto-push-repos.json",
    [string]$LogPath = "F:\ai-workspace\ACTION-LOG.md",
    [string]$OnlyPath = ""
)

$ErrorActionPreference = "Continue"
$script:RunResults = @()

function Write-AutoPushLog {
    param(
        [string]$Title,
        [string]$Result,
        [string]$Detail
    )
    if (-not (Test-Path $LogPath)) { return }
    $date = Get-Date -Format "yyyy-MM-dd"
    $actor = "auto-push.ps1"
    $entry = @"

### $date — $Title

| Field | Value |
|---|---|
| **Actor** | $actor |
| **Action** | Auto-push run |
| **Target** | $Detail |
| **Result** | $Result |
| **Next step** | $(if ($Result -eq "blocked") { "Set GH_TOKEN or run gh auth login (interactive, outside agent)" } else { "none" }) |

"@
    $content = Get-Content -Raw -Path $LogPath
    $marker = "## Log entries"
    $idx = $content.IndexOf($marker)
    if ($idx -lt 0) {
        Add-Content -Path $LogPath -Value $entry
        return
    }
    $insertAt = $idx + $marker.Length
    $newContent = $content.Substring(0, $insertAt) + "`n`n" + $entry.TrimEnd() + $content.Substring($insertAt)
    [System.IO.File]::WriteAllText($LogPath, $newContent)
}

function Test-GitHubAuthAvailable {
    if ($env:GH_TOKEN) {
        $null = gh api user -q .login 2>$null
        if ($LASTEXITCODE -eq 0) { return $true }
    }
    gh auth status 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Ensure-GitRemote {
    param(
        [string]$RepoPath,
        [string]$RemoteSlug,
        [string]$Branch
    )
    Push-Location $RepoPath
    try {
        $url = "https://github.com/$RemoteSlug.git"
        $origin = git remote get-url origin 2>$null
        if ($LASTEXITCODE -ne 0) {
            git remote add origin $url
            return
        }
        if ($origin -ne $url -and $origin -ne "git@github.com:${RemoteSlug}.git") {
            Write-Host "  [warn] origin is $origin (expected $url); not changing"
        }
    } finally {
        Pop-Location
    }
}

function Test-RepoExistsOnGitHub {
    param([string]$RemoteSlug)
    gh repo view $RemoteSlug --json name -q .name 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function New-GitHubRepoIfMissing {
    param(
        [string]$RepoPath,
        [string]$RemoteSlug,
        [string]$Branch
    )
    if (Test-RepoExistsOnGitHub -RemoteSlug $RemoteSlug) { return $true }
    Write-Host "  Creating GitHub repo $RemoteSlug ..."
    Push-Location $RepoPath
    try {
        gh repo create $RemoteSlug --private --source=. --remote=origin --push=false 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            gh repo create $RemoteSlug --private 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { return $false }
            Ensure-GitRemote -RepoPath $RepoPath -RemoteSlug $RemoteSlug -Branch $Branch
        }
        return $true
    } finally {
        Pop-Location
    }
}

function Get-AheadCount {
    param([string]$Branch)
    $upstream = git rev-parse --abbrev-ref "${Branch}@{upstream}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        $localCount = (git rev-list --count $Branch 2>$null)
        if ($LASTEXITCODE -eq 0 -and [int]$localCount -gt 0) { return [int]$localCount }
        return 0
    }
    $count = git rev-list --count "${Branch}@{upstream}..${Branch}" 2>$null
    if ($LASTEXITCODE -ne 0) { return 0 }
    return [int]$count
}

function Invoke-RepoPush {
    param(
        [string]$RepoPath,
        [string]$RemoteSlug,
        [string]$Branch
    )
    $name = Split-Path $RepoPath -Leaf
    if (-not (Test-Path $RepoPath)) {
        return @{ name = $name; status = "skip"; msg = "path missing" }
    }
    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        return @{ name = $name; status = "skip"; msg = "not a git repo" }
    }

    Push-Location $RepoPath
    try {
        $current = git rev-parse --abbrev-ref HEAD 2>$null
        if ($current -ne $Branch) {
            return @{ name = $name; status = "skip"; msg = "on branch $current (want $Branch)" }
        }

        Ensure-GitRemote -RepoPath $RepoPath -RemoteSlug $RemoteSlug -Branch $Branch
        $ahead = Get-AheadCount -Branch $Branch
        if ($ahead -le 0) {
            return @{ name = $name; status = "ok"; msg = "nothing to push" }
        }

        if (-not (New-GitHubRepoIfMissing -RepoPath $RepoPath -RemoteSlug $RemoteSlug -Branch $Branch)) {
            return @{ name = $name; status = "fail"; msg = "could not create or access remote $RemoteSlug" }
        }

        Write-Host "  Pushing $ahead commit(s) to origin $Branch ..."
        git push -u origin $Branch 2>&1 | ForEach-Object { Write-Host "    $_" }
        if ($LASTEXITCODE -ne 0) {
            return @{ name = $name; status = "fail"; msg = "git push failed (exit $LASTEXITCODE)" }
        }
        return @{ name = $name; status = "ok"; msg = "pushed $ahead commit(s)" }
    } finally {
        Pop-Location
    }
}

# --- main ---
if (-not (Test-Path $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath"
    exit 1
}

$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$repos = @($config.repos)
if ($OnlyPath) {
    $norm = ($OnlyPath -replace '\\', '/').TrimEnd('/')
    $repos = @($repos | Where-Object { ($_.path -replace '\\', '/').TrimEnd('/') -eq $norm })
}

if (-not (Test-GitHubAuthAvailable)) {
    Write-Host "GitHub auth unavailable (no GH_TOKEN and gh auth not logged in). Skipping all pushes."
    $detail = ($repos | ForEach-Object { $_.path }) -join "; "
    Write-AutoPushLog -Title "Auto-push skipped (no auth)" -Result "blocked" -Detail $detail
    exit 0
}

if ($env:GH_TOKEN) {
    gh auth setup-git 2>$null | Out-Null
}

Write-Host "Auto-push starting ($($repos.Count) repo(s))..."
$summary = @()
foreach ($r in $repos) {
    $path = ($r.path -replace '/', '\')
    Write-Host "`n[$($r.remote)] $path"
    $result = Invoke-RepoPush -RepoPath $path -RemoteSlug $r.remote -Branch $r.branch
    $script:RunResults += $result
    $summary += "$($result.name): $($result.msg)"
    Write-Host "  -> $($result.status): $($result.msg)"
}

$failures = ($script:RunResults | Where-Object { $_.status -eq "fail" }).Count
$title = if ($failures -gt 0) { "Auto-push partial/failed" } else { "Auto-push completed" }
$resultLabel = if ($failures -gt 0) { "partial" } else { "success" }
Write-AutoPushLog -Title $title -Result $resultLabel -Detail (($summary) -join " | ")
if ($failures -gt 0) { exit 2 }
exit 0
