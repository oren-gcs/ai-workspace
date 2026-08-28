# spotify-auth.ps1 — Open Spotify OAuth (PKCE) for Grok Social Bot.
# Never prints secrets from .env. Refresh token shown only in browser callback page.
param(
    [string]$EnvFile = "F:\ai-workspace\projects\grok-social-bot\local\.env",
    [string]$LocalDir = "F:\ai-workspace\projects\grok-social-bot\local"
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

function New-RandomBytesBase64Url {
    param([int]$Length = 32)
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $b64 = [Convert]::ToBase64String($bytes)
    return $b64.TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-Sha256Base64Url {
    param([string]$Text)
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Text)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    $b64 = [Convert]::ToBase64String($hash)
    return $b64.TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

$clientId = Read-EnvValue -Path $EnvFile -Key "SPOTIFY_CLIENT_ID"
$redirectUri = Read-EnvValue -Path $EnvFile -Key "SPOTIFY_REDIRECT_URI"
if (-not $redirectUri) {
    $redirectUri = "http://127.0.0.1:3847/auth/spotify/callback"
}

$host_ = Read-EnvValue -Path $EnvFile -Key "BOT_HOST"
if (-not $host_) { $host_ = "127.0.0.1" }
$port = Read-EnvValue -Path $EnvFile -Key "BOT_PORT"
if (-not $port) { $port = "3847" }

Write-Host ""
Write-Host "=== Spotify OAuth (PKCE) ===" -ForegroundColor Cyan
Write-Host ""

if (-not $clientId) {
    Write-Host "SPOTIFY_CLIENT_ID not set in .env" -ForegroundColor Red
    Write-Host "  1. Create app: https://developer.spotify.com/dashboard"
    Write-Host "  2. Add redirect URI: $redirectUri"
    Write-Host "  3. Copy Client ID to local/.env"
    Write-Host ""
    Write-Host "Full guide: F:\ai-workspace\projects\grok-social-bot\docs\SPOTIFY-SETUP.md"
    exit 1
}

# Health check — bot must be running for callback
$healthUrl = "http://${host_}:${port}/health"
try {
    $health = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 3
    if ($health.StatusCode -ne 200) {
        throw "unexpected status"
    }
    Write-Host "Bot server: OK ($healthUrl)" -ForegroundColor Green
} catch {
    Write-Host "Bot server not running at $healthUrl" -ForegroundColor Yellow
    Write-Host "  Start in another terminal:"
    Write-Host "    cd $LocalDir"
    Write-Host "    npm run dry-run"
    Write-Host ""
    $cont = Read-Host "Continue anyway? (y/N)"
    if ($cont -ne "y" -and $cont -ne "Y") { exit 1 }
}

$codeVerifier = New-RandomBytesBase64Url -Length 32
$codeChallenge = Get-Sha256Base64Url -Text $codeVerifier
$state = -join ((48..57) + (97..102) | Get-Random -Count 32 | ForEach-Object { [char]$_ })

$pending = @{
    codeVerifier = $codeVerifier
    codeChallenge = $codeChallenge
    state = $state
    createdAt = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
}
$pendingPath = Join-Path $LocalDir ".spotify-oauth-pending.json"
$pending | ConvertTo-Json | Set-Content -Path $pendingPath -Encoding UTF8
Write-Host "PKCE state saved: $pendingPath" -ForegroundColor DarkGray

$scopes = @(
    "user-read-recently-played",
    "user-read-currently-playing",
    "playlist-read-private",
    "user-top-read"
) -join " "

$authUrl = "https://accounts.spotify.com/authorize?" + (
    "client_id=$([uri]::EscapeDataString($clientId))" +
    "&response_type=code" +
    "&redirect_uri=$([uri]::EscapeDataString($redirectUri))" +
    "&code_challenge_method=S256" +
    "&code_challenge=$([uri]::EscapeDataString($codeChallenge))" +
    "&state=$([uri]::EscapeDataString($state))" +
    "&scope=$([uri]::EscapeDataString($scopes))"
)

Write-Host ""
Write-Host "Opening browser for Spotify authorization..." -ForegroundColor Cyan
Write-Host "Redirect URI: $redirectUri"
Write-Host ""
Write-Host "After approval:"
Write-Host "  1. Browser shows refresh token on success page"
Write-Host "  2. Copy SPOTIFY_REFRESH_TOKEN to local/.env"
Write-Host "  3. Restart bot"
Write-Host ""
Write-Host "Auth URL (if browser does not open):" -ForegroundColor DarkGray
Write-Host $authUrl
Write-Host ""

Start-Process $authUrl
