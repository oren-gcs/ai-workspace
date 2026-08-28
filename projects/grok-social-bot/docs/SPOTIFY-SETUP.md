# Spotify Setup — Grok Social Bot

**Honest status:** Spotify is **not connected** until you create a developer app, complete OAuth, and set `SPOTIFY_REFRESH_TOKEN` in `local/.env`.

Spotify listening activity feeds the **Grok WhatsApp digest** alongside social mentions — e.g. "what you listened to today" and top artists.

---

## Personal vs work account

| Account | Use when |
|---------|----------|
| **Personal Spotify** | Daily listening digest reflects your real habits (recommended for this bot) |
| **Work / brand** | Only if monitoring a shared or creator account |

Meta/Facebook uses the **Chrome work profile** (`oren@gcs-tech.org`). Spotify is independent — log into [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) with the account that owns the listening history you want in digests.

---

## Step 1 — Create Spotify app

1. Open https://developer.spotify.com/dashboard
2. Log in (personal or work — see table above)
3. **Create app** → name: `grok-social-bot`
4. Redirect URI: `http://127.0.0.1:3847/auth/spotify/callback`
5. Copy **Client ID** and **Client Secret** to `.env`:
   ```
   ENABLE_SPOTIFY=true
   SPOTIFY_CLIENT_ID=
   SPOTIFY_CLIENT_SECRET=
   SPOTIFY_REDIRECT_URI=http://127.0.0.1:3847/auth/spotify/callback
   ```

Spotify allows `127.0.0.1` redirect URIs for local development.

---

## Step 2 — OAuth scopes (why each)

| Scope | Purpose in digest |
|-------|-------------------|
| `user-read-recently-played` | Recent tracks for "what you listened to" section |
| `user-read-currently-playing` | Live "now playing" line in digest |
| `playlist-read-private` | Private playlist context (future mood signals) |
| `user-top-read` | Top artists/tracks over time |

Defined in `local/src/connectors/spotify-auth.ts` as `SPOTIFY_SCOPES`.

---

## Step 3 — PKCE OAuth (local auth)

### Option A — PowerShell helper (recommended)

1. Start the bot (callback server must be running):
   ```powershell
   cd F:\ai-workspace\projects\grok-social-bot\local
   npm run dry-run
   ```
2. In another terminal:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\projects\grok-social-bot\scripts\spotify-auth.ps1
   ```
3. Browser opens → approve Spotify access
4. Callback page shows `SPOTIFY_REFRESH_TOKEN` — copy to `local/.env`
5. Restart bot

### Option B — VS Code task

**Tasks → Run Task → Spotify OAuth (open auth URL)**

Requires bot running on `127.0.0.1:3847`.

### Option C — Bot redirect endpoint

With bot running and `SPOTIFY_CLIENT_ID` set, open:

`http://127.0.0.1:3847/auth/spotify/start`

---

## Step 4 — Verify

```powershell
cd F:\ai-workspace\projects\grok-social-bot\local
npm run dry-run
```

Expected when configured:
- `[cycle] spotify: ready`
- Digest preview includes `[spotify] Now playing:` or `[spotify] Recent:` lines
- Grok summarizes listening alongside mentions

---

## How Spotify appears in WhatsApp digest

Each poll cycle (`POLL_INTERVAL_MS`, default 5 min):

1. `SpotifyConnector.fetchDigestLines()` calls Web API:
   - `/me/player/currently-playing`
   - `/me/player/recently-played`
   - `/me/top/artists`
2. Lines formatted as `[spotify] ...` context
3. `GrokClient.summarizeDigest()` merges social mentions + Spotify activity
4. WhatsApp digest includes a brief listening summary (mood, new artists, now playing)

Example Grok output:
> **Listening:** Mostly focus instrumentals this morning. Now playing: *Artist — Track*. Top artist this month: …

---

## Token refresh

Access tokens expire (~1 hour). The connector calls `refreshAccessToken()` using `SPOTIFY_REFRESH_TOKEN` automatically — no manual refresh needed after initial OAuth.

**Never commit** refresh tokens. Store only in `local/.env` (gitignored).

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Invalid redirect URI | Must match exactly in Dashboard and `.env` |
| `invalid_grant` on callback | PKCE state expired (10 min) — re-run `spotify-auth.ps1` |
| No refresh token | Revoke app at spotify.com/account/apps, re-authorize |
| `spotify: awaiting token` | Set `SPOTIFY_REFRESH_TOKEN` after OAuth |
| Bot callback 404 | Start bot first (`npm run dry-run`) |

---

## Update connection map

After OAuth, edit `F:\ai-workspace\config\accounts-connection-map.json` → `grok_bot.spotify`:

```json
"spotify": {
  "developerAppName": "grok-social-bot",
  "redirectUri": "http://127.0.0.1:3847/auth/spotify/callback",
  "accountHint": "personal or work — see SPOTIFY-SETUP.md"
}
```

Do **not** store tokens in this file.

---

## Links

- [Spotify Web API](https://developer.spotify.com/documentation/web-api)
- [Authorization Code PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow)
- Connected platforms index: [CONNECTED-PLATFORMS.md](CONNECTED-PLATFORMS.md)
