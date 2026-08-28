# setup-meta-webhook.ps1 — Print Meta webhook URLs and verify-token checklist.
# Never prints secret values from .env.
param(
    [string]$EnvFile = "F:\ai-workspace\projects\grok-social-bot\local\.env"
)

$ErrorActionPreference = "Stop"

function Read-EnvValue {
    param([string]$Path, [string]$Key)
    if (-not (Test-Path $Path)) { return "" }
    foreach ($line in Get-Content $Path) {
        if ($line -match "^\s*#") { continue }
        if ($line -match "^\s*$Key\s*=\s*(.*)$") {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return ""
}

function Read-EnvFirst {
    param([string]$Path, [string[]]$Keys)
    foreach ($k in $Keys) {
        $v = Read-EnvValue -Path $Path -Key $k
        if ($v) { return $v }
    }
    return ""
}

$host_ = Read-EnvFirst $EnvFile @("BOT_HOST")
if (-not $host_) { $host_ = "127.0.0.1" }

$port = Read-EnvFirst $EnvFile @("BOT_PORT")
if (-not $port) { $port = "3847" }

$webhookPath = Read-EnvFirst $EnvFile @("WEBHOOK_PATH")
if (-not $webhookPath) { $webhookPath = "/webhook/whatsapp" }

$verifyToken = Read-EnvFirst $EnvFile @("WEBHOOK_VERIFY_TOKEN", "META_WEBHOOK_VERIFY_TOKEN")
$publicBase = Read-EnvFirst $EnvFile @("PUBLIC_WEBHOOK_BASE_URL")
$provider = Read-EnvFirst $EnvFile @("WHATSAPP_PROVIDER")
if (-not $provider) { $provider = "none" }

Write-Host ""
Write-Host "=== Meta WhatsApp Webhook Setup ===" -ForegroundColor Cyan
Write-Host "Provider: $provider"
Write-Host ""

$localUrl = "http://${host_}:${port}${webhookPath}"
Write-Host "Local callback (Meta cannot reach this directly):" -ForegroundColor Yellow
Write-Host "  $localUrl"
Write-Host ""

if ($publicBase) {
    $publicUrl = ($publicBase.TrimEnd("/")) + $webhookPath
    Write-Host "Public callback (register this in Meta Console):" -ForegroundColor Green
    Write-Host "  $publicUrl"
} else {
    Write-Host "Public callback: NOT SET" -ForegroundColor Yellow
    Write-Host "  1. Run: ngrok http $port"
    Write-Host "  2. Set PUBLIC_WEBHOOK_BASE_URL=https://xxxx.ngrok-free.app in .env"
    Write-Host "  3. Re-run this script"
}

Write-Host ""
Write-Host "Verify token (WEBHOOK_VERIFY_TOKEN):" -ForegroundColor Cyan
if ($verifyToken) {
    Write-Host "  SET (length $($verifyToken.Length) chars) — paste same value in Meta Console"
} else {
    Write-Host "  NOT SET — generate a random string and add to .env:" -ForegroundColor Red
    Write-Host "  WEBHOOK_VERIFY_TOKEN=<random-string>"
}

Write-Host ""
Write-Host "Meta Console steps:" -ForegroundColor Cyan
Write-Host "  1. https://developers.facebook.com/ → Your App → WhatsApp → Configuration"
Write-Host "  2. Callback URL: <public URL above>/webhook/whatsapp"
Write-Host "  3. Verify token: same as WEBHOOK_VERIFY_TOKEN"
Write-Host "  4. Subscribe to: messages"
Write-Host "  5. Start bot: npm run dry-run (in local/) before clicking Verify"
Write-Host ""
Write-Host "Full wizard: F:\ai-workspace\projects\grok-social-bot\docs\CONFIG-META-WHATSAPP-FACEBOOK.md"
Write-Host ""
