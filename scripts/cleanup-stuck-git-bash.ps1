# cleanup-stuck-git-bash.ps1 — Kill hung Git Bash shells from Cursor deploy-on-aws validate-drawio hook (stdin blocked on `cat`).
param(
    [switch]$WhatIf
)
$pattern = 'validate-drawio'
$procs = Get-CimInstance Win32_Process -Filter "Name='bash.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -match $pattern }
$count = @($procs).Count
if ($count -eq 0) {
    Write-Host "No stuck validate-drawio bash processes ($pattern)."
    exit 0
}
foreach ($p in $procs) {
    if ($WhatIf) {
        Write-Host "Would stop PID $($p.ProcessId)"
    } else {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
}
if (-not $WhatIf) {
    Write-Host "Stopped $count validate-drawio bash process(es)."
}
exit 0
