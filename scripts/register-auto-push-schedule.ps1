# register-auto-push-schedule.ps1
# Run once: powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\register-auto-push-schedule.ps1
param(
    [string]$TaskName = "ai-workspace-auto-push",
    [string]$ScriptPath = "F:\ai-workspace\scripts\auto-push.ps1",
    [ValidateSet("Hourly", "Daily")]
    [string]$Frequency = "Hourly"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $ScriptPath)) { throw "Script not found: $ScriptPath" }

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
$trigger = if ($Frequency -eq "Daily") {
    New-ScheduledTaskTrigger -Daily -At "09:00"
} else {
    New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration ([TimeSpan]::MaxValue)
}
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
Write-Host "Registered scheduled task '$TaskName' ($Frequency). Set user env GH_TOKEN for unattended push."
Write-Host "Remove: Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
