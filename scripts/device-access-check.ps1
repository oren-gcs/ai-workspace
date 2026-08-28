# device-access-check.ps1 — Quick diagnostic for device/access blockers.
# Never prints secret values.
param(
    [switch]$Json
)

$ErrorActionPreference = "Continue"
$results = [ordered]@{}

function Add-Check {
    param([string]$Name, [string]$Status, [string]$Detail)
    $script:results[$Name] = @{ status = $Status; detail = $Detail }
}

# --- GitHub ---
$ghVersion = (gh --version 2>$null | Select-Object -First 1)
if (-not $ghVersion) {
    Add-Check "gh_installed" "fail" "gh not found in PATH"
} else {
    Add-Check "gh_installed" "ok" $ghVersion.Trim()
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $login = (gh api user -q .login 2>$null)
        Add-Check "gh_auth" "ok" $(if ($login) { "logged in as $login" } else { "logged in" })
    } else {
        Add-Check "gh_auth" "fail" "not logged in"
    }
}

$ghTokenSet = [bool][System.Environment]::GetEnvironmentVariable("GH_TOKEN", "User")
Add-Check "gh_token_user_env" $(if ($ghTokenSet) { "ok" } else { "warn" }) $(if ($ghTokenSet) { "set (value hidden)" } else { "not set" })

$gcmEntries = @(cmdkey /list 2>$null | Select-String -Pattern "github|git:https://github.com")
Add-Check "gcm_github_entry" $(if ($gcmEntries.Count -gt 0) { "ok" } else { "warn" }) "$($gcmEntries.Count) matching credential(s)"

# --- Paths ---
Add-Check "path_f_ai_workspace" $(if (Test-Path "F:\ai-workspace") { "ok" } else { "fail" }) "F:\ai-workspace"
Add-Check "path_doc_power" $(if (Test-Path "F:\DevSecOps\projects\doc-power-local-k8s") { "ok" } else { "fail" }) "doc-power-local-k8s"

# --- Elevation ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Add-Check "elevation" $(if ($isAdmin) { "ok" } else { "info" }) $(if ($isAdmin) { "running elevated" } else { "medium integrity (normal for agents)" })

# --- Docker ---
$dockerVersion = (docker version --format "{{.Server.Version}}" 2>$null)
if ($dockerVersion) {
    Add-Check "docker" "ok" "server $dockerVersion"
    $port9090 = @(docker ps --format "{{.Names}}" --filter "publish=9090" 2>$null)
    Add-Check "docker_port_9090" $(if ($port9090.Count -gt 0) { "warn" } else { "ok" }) $(if ($port9090.Count -gt 0) { "in use by: $($port9090 -join ', ')" } else { "free" })
} else {
    Add-Check "docker" "fail" "docker not reachable"
}

# --- WSL gh (best effort) ---
try {
    $wslGh = wsl -d Ubuntu-24.04 -- bash -lc "gh auth status 2>&1 | head -1" 2>$null
    if ($wslGh -match "Logged in") {
        Add-Check "wsl_gh_auth" "ok" $wslGh.Trim()
    } elseif ($wslGh -match "not logged") {
        Add-Check "wsl_gh_auth" "fail" "not logged in"
    } else {
        Add-Check "wsl_gh_auth" "warn" $(if ($wslGh) { $wslGh.Trim() } else { "wsl check skipped" })
    }
} catch {
    Add-Check "wsl_gh_auth" "warn" "wsl unavailable"
}

# --- Quarantine ---
Add-Check "secrets_quarantine" $(if (Test-Path "F:\_archive\secrets-quarantine") { "ok" } else { "warn" }) "F:\_archive\secrets-quarantine"

# --- Output ---
if ($Json) {
    $results | ConvertTo-Json -Depth 3
} else {
    Write-Host "=== device-access-check ===" -ForegroundColor Cyan
    foreach ($key in $results.Keys) {
        $r = $results[$key]
        $color = switch ($r.status) {
            "ok" { "Green" }
            "fail" { "Red" }
            "warn" { "Yellow" }
            default { "Gray" }
        }
        Write-Host ("[{0}] {1,-22} {2}" -f $r.status.ToUpper(), $key, $r.detail) -ForegroundColor $color
    }
    $failCount = ($results.Values | Where-Object { $_.status -eq "fail" }).Count
    Write-Host ""
    if ($failCount -gt 0) {
        Write-Host "Failures: $failCount — run sync-gh-auth.ps1 or see DEVICE-ACCESS-PLAYBOOK.md" -ForegroundColor Yellow
        exit 1
    }
    exit 0
}
