# register-start-all-local-schedule.ps1 — Optional scheduled idempotent local service start
param(
    [string]$TaskName = "ai-workspace-start-all-local",
    [string]$ScriptPath = "F:\ai-workspace\scripts\start-all-local.ps1",
    [string]$DailyAt = "08:00"
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $ScriptPath)) { throw "Script not found: $ScriptPath" }

$args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -NoOpen -SkipIfRunning"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $args
$trigger = New-ScheduledTaskTrigger -Daily -At $DailyAt
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
Write-Host "Registered '$TaskName' daily at $DailyAt with -NoOpen -SkipIfRunning (Hidden)."
Write-Host "Remove: Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
