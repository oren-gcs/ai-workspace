$log = 'F:\ai-workspace\logs\elevated-quarantine-diag.log'
$src = 'F:\gcs-tech-su_credentials (1).csv'
$lines = @("diag $(Get-Date -Format o)", "elevated: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))")
$lines += (cmd /c "icacls `"$src`" 2>&1")
$lines += (cmd /c "move /Y `"$src`" `"F:\_archive\secrets-quarantine\gcs-tech-su_credentials-2026-08-28.csv`" 2>&1")
$lines += "src: $(Test-Path -LiteralPath $src)"
$lines += "dest: $(Test-Path 'F:\_archive\secrets-quarantine\gcs-tech-su_credentials-2026-08-28.csv')"
$lines | Set-Content $log
