# register-git-background-worker.ps1 — Optional 30-minute git fetch/push worker
param(
    [string]$TaskName = "ai-workspace-git-background-worker",
    [string]$ScriptPath = "F:\ai-workspace\scripts\git-background-worker.ps1"
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $ScriptPath)) { throw "Script not found: $ScriptPath" }
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
Write-Host "Registered '$TaskName' every 30 minutes (Hidden). Remove: Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"

