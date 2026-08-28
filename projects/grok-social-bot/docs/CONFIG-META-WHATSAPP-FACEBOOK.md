# Meta WhatsApp + Facebook Setup Wizard

Step-by-step guide to connect **WhatsApp Business Cloud API** and **Facebook Page** monitoring for the Grok Social Bot.

**Status:** Not connected until you complete the steps below and fill `local/.env`. The bot defaults to `DRY_RUN=true` and `ALLOW_OUTBOUND_WHATSAPP=false`.

---

## Before you start

| Item | Value |
|------|-------|
| Chrome profile | **Work** — `oren@gcs-tech.org` (Profile 1 or 12 in Chrome) |
| Meta login | Same work Google account |
| Bot bind address | `127.0.0.1:3847` (never expose without tunnel) |
| Env file | `F:\ai-workspace\projects\grok-social-bot\local\.env` |
| Connection map | `F:\ai-workspace\config\accounts-connection-map.json` → `grok_bot` |

**Never commit** `.env`, tokens, or app secrets to git.

---

## Step 1 — Meta Business account

1. Open Chrome with the **oren@gcs-tech.org** work profile.
2. Go to [Meta Business Suite](https://business.facebook.com/).
3. Create or select a Business Portfolio for your brand (e.g. GCS-tech).
4. Note the Business Manager ID (Settings → Business info).

---

## Step 2 — Create Meta Developer App

1. Go to [developers.facebook.com](https://developers.facebook.com/) — log in with **oren@gcs-tech.org**.
2. **My Apps** → **Create App** → type **Business**.
3. App name suggestion: `grok-social-bot` (or your brand name).
4. Connect to the Business Portfolio from Step 1.
5. Copy **App ID** and **App Secret** (Settings → Basic):
   ```
   META_APP_ID=
   META_APP_SECRET=
   ```

---

## Step 3 — Add WhatsApp product

1. In your app dashboard → **Add Product** → **WhatsApp** → **Set up**.
2. Select or create a **WhatsApp Business Account** (WABA).
3. Open **API Setup** and copy:
   - **Phone number ID** → `WHATSAPP_PHONE_NUMBER_ID`
   - **WhatsApp Business Account ID** → `WHATSAPP_BUSINESS_ACCOUNT_ID`
4. Generate a **temporary access token** (24h, dev only) OR create a **System User** token (production):
   - Business Settings → Users → System Users → Generate token
   - Scopes: `whatsapp_business_messaging`, `whatsapp_business_management`
   ```
   WHATSAPP_ACCESS_TOKEN=
   ```

---

## Step 4 — Add test recipient phone

1. In WhatsApp → **API Setup** → **To** field → **Manage phone number list**.
2. Add your phone in E.164 format (e.g. `+972501234567`).
3. Complete SMS/voice OTP verification.
4. Set in `.env`:
   ```
   WHATSAPP_TEST_NUMBER=+972501234567
   ```

---

## Step 5 — Webhook verify token

1. Choose a random string (e.g. `openssl rand -hex 16` or any password manager).
2. Set in `.env`:
   ```
   WEBHOOK_VERIFY_TOKEN=your-random-string-here
   ```
3. Run the setup helper:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\projects\grok-social-bot\scripts\setup-meta-webhook.ps1
   ```

---

## Step 6 — Local webhook + ngrok

Meta cannot reach `127.0.0.1`. For local development:

1. Start the bot (dry-run is fine for webhook verification):
   ```powershell
   cd F:\ai-workspace\projects\grok-social-bot\local
   npm run dry-run
   ```
2. In another terminal, start a tunnel:
   ```powershell
   ngrok http 3847
   ```
3. Copy the HTTPS URL (e.g. `https://abc123.ngrok-free.app`) to `.env`:
   ```
   PUBLIC_WEBHOOK_BASE_URL=https://abc123.ngrok-free.app
   ```
4. In Meta Developer Console → WhatsApp → **Configuration** → **Webhook**:
   - **Callback URL:** `https://abc123.ngrok-free.app/webhook/whatsapp`
   - **Verify token:** same as `WEBHOOK_VERIFY_TOKEN`
   - Click **Verify and save**
   - Subscribe to **messages** field

The bot answers Meta's `hub.challenge` GET on `/webhook/whatsapp`.

---

## Step 7 — Facebook Page (optional, for mention monitoring)

1. In the same Meta app, add **Facebook Login** (if you need OAuth later) and ensure **Pages** permissions.
2. Link your Facebook Page to the Business Portfolio.
3. Generate a **Page access token** with scopes:
   - `pages_read_engagement`
   - `pages_show_list`
   - `pages_read_user_content` (for tagged posts)
4. Set in `.env`:
   ```
   ENABLE_FACEBOOK=true
   FACEBOOK_PAGE_ID=
   FACEBOOK_PAGE_ACCESS_TOKEN=
   ```

Graph API endpoints used by the bot: `/{page-id}/feed` and `/{page-id}/tagged`.

---

## Step 8 — Final `.env` checklist

```env
WHATSAPP_PROVIDER=meta
META_APP_ID=
META_APP_SECRET=
WHATSAPP_ACCESS_TOKEN=
WHATSAPP_PHONE_NUMBER_ID=
WHATSAPP_BUSINESS_ACCOUNT_ID=
WEBHOOK_VERIFY_TOKEN=
WHATSAPP_TEST_NUMBER=+1...
ALLOW_OUTBOUND_WHATSAPP=false
DRY_RUN=true
PUBLIC_WEBHOOK_BASE_URL=https://....ngrok-free.app

# Optional Facebook Page
ENABLE_FACEBOOK=false
FACEBOOK_PAGE_ID=
FACEBOOK_PAGE_ACCESS_TOKEN=
```

---

## Step 9 — Test (dry-run first)

VS Code: **Tasks → Run Task → Configure Meta WhatsApp (dry-run test)**

Or manually:
```powershell
cd F:\ai-workspace\projects\grok-social-bot\local
npm run dry-run
```

Expected output when keys are missing:
- Lists each Meta env var with ✓/✗
- `DRY_RUN` — no HTTP send
- Digest preview in console

---

## Step 10 — First real WhatsApp send

Only after confirming `WHATSAPP_TEST_NUMBER` is correct:

```env
DRY_RUN=false
ALLOW_OUTBOUND_WHATSAPP=true
```

Restart the bot. It will send only to `WHATSAPP_TEST_NUMBER`.

---

## Step 11 — Update connection map

Edit `F:\ai-workspace\config\accounts-connection-map.json` → `grok_bot`:

```json
"meta": {
  "developerAppId": "<META_APP_ID>",
  "whatsappPhoneNumberId": "<WHATSAPP_PHONE_NUMBER_ID>",
  "facebookPageId": "<FACEBOOK_PAGE_ID or null>",
  "chromeProfile": "oren@gcs-tech.org"
},
"status": "meta_whatsapp_configured"
```

Do **not** store tokens in this file.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Webhook verify fails (403) | `WEBHOOK_VERIFY_TOKEN` must match Meta Console exactly; bot must be running |
| ngrok URL changed | Update `PUBLIC_WEBHOOK_BASE_URL` and re-register webhook in Meta |
| WhatsApp 403 / OAuthException | Token expired — regenerate System User token |
| Recipient not in allow list | Add phone in API Setup → Manage phone number list |
| No outbound send | Check `DRY_RUN`, `ALLOW_OUTBOUND_WHATSAPP`, `WHATSAPP_TEST_NUMBER` |
| Facebook tagged empty | Grant `pages_read_engagement`; Page must be Business type |

Run device check: `F:\ai-workspace\scripts\device-access-check.ps1`

---

## Links

- [WhatsApp Cloud API docs](https://developers.facebook.com/docs/whatsapp/cloud-api/)
- [Meta Graph API — Page feed](https://developers.facebook.com/docs/graph-api/reference/page/feed/)
- [System User tokens](https://developers.facebook.com/docs/marketing-api/system-users)
- Bot WhatsApp overview: [WHATSAPP-SETUP.md](WHATSAPP-SETUP.md)
- Social accounts: [SOCIAL-ACCOUNTS.md](SOCIAL-ACCOUNTS.md)
