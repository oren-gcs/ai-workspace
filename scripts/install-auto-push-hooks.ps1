# install-auto-push-hooks.ps1 — Install lightweight post-commit hooks (background, non-blocking)
param([switch]$WhatIf)

$template = Join-Path $PSScriptRoot "post-commit.hook.template"
if (-not (Test-Path $template)) { throw "Missing $template" }

$targets = @(
    "F:\DevSecOps\projects\doc-power-local-k8s",
    "F:\ai-workspace"
)
foreach ($repo in $targets) {
    $hooksDir = Join-Path $repo ".git\hooks"
    $dest = Join-Path $hooksDir "post-commit"
    if (-not (Test-Path $hooksDir)) { Write-Warning "Skip (no .git): $repo"; continue }
    if ($WhatIf) { Write-Host "Would install: $dest"; continue }
    Copy-Item -Path $template -Destination $dest -Force
    Write-Host "Installed post-commit hook: $repo"
}
Write-Host "Hooks call auto-push.ps1 with -OnlyPath for that repo only."
