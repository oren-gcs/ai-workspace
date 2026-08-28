# WhatsApp Setup — Grok Social Bot

**Honest status:** WhatsApp is **not connected** until you complete one of the flows below and set env vars in `local/.env`. The bot defaults to `DRY_RUN=true` and `ALLOW_OUTBOUND_WHATSAPP=false`.

## Choose a provider

| Provider | Best for | Env prefix |
|----------|----------|------------|
| **Twilio sandbox** | Local dev, fastest first message | `TWILIO_*` |
| **Meta Cloud API** | Production, your Business number | `META_*` |

Set `WHATSAPP_PROVIDER=twilio` or `WHATSAPP_PROVIDER=meta`.

---

## Option A — Twilio WhatsApp Sandbox (recommended for dev)

1. Create account: https://www.twilio.com/try-twilio
2. Console → **Messaging** → **Try it out** → **Send a WhatsApp message**
3. Join sandbox: send the displayed code (e.g. `join <word>-<word>`) from your phone to **+1 415 523 8886**
4. Copy to `.env`:
   ```
   WHATSAPP_PROVIDER=twilio
   TWILIO_ACCOUNT_SID=AC...
   TWILIO_AUTH_TOKEN=...
   TWILIO_WHATSAPP_FROM=whatsapp:+14155238886
   WHATSAPP_TEST_NUMBER=whatsapp:+<your_e164>
   ```
5. For a real send (after you confirm the test number):
   ```
   DRY_RUN=false
   ALLOW_OUTBOUND_WHATSAPP=true
   ```

Docs: https://www.twilio.com/docs/whatsapp/sandbox

---

## Option B — Meta WhatsApp Business Cloud API

### Prerequisites

- Meta Business account
- Facebook Developer app with **WhatsApp** product added
- Verified business (for production; test numbers available in dev mode)

### Steps

1. https://developers.facebook.com/ → Create app → Business → Add **WhatsApp**
2. **API Setup** → copy **Phone number ID** and generate **temporary access token** (or system user token for prod)
3. Set `.env`:
   ```
   WHATSAPP_PROVIDER=meta
   META_WHATSAPP_TOKEN=EAA...
   META_WHATSAPP_PHONE_NUMBER_ID=...
   META_WHATSAPP_BUSINESS_ACCOUNT_ID=...
   META_WEBHOOK_VERIFY_TOKEN=<random-string-you-choose>
   META_APP_SECRET=...
   ```
4. **Webhook** (incoming messages):
   - Callback URL: `https://<public-host>/webhook/whatsapp`
   - Verify token: same as `META_WEBHOOK_VERIFY_TOKEN`
   - Subscribe to `messages` field

### Local webhook (127.0.0.1)

Meta cannot reach `127.0.0.1`. For local dev:

1. Run bot: `npm start` (binds `BOT_HOST=127.0.0.1`, `BOT_PORT=3847`)
2. Tunnel: `ngrok http 3847` (or Cloudflare Tunnel)
3. Set `PUBLIC_WEBHOOK_BASE_URL=https://xxxx.ngrok-free.app`
4. Register webhook in Meta: `https://xxxx.ngrok-free.app/webhook/whatsapp`

The bot answers Meta's `hub.challenge` GET verification on that path.

### Phone number verification

- **Test numbers:** Meta Developer Console → WhatsApp → API Setup → add recipient phone (SMS/voice OTP)
- **Production:** Register a dedicated WhatsApp Business number through Meta Business Manager

---

## Safety gates (required)

| Variable | Purpose |
|----------|---------|
| `WHATSAPP_TEST_NUMBER` | E.164 or `whatsapp:+...` — only send here until prod |
| `ALLOW_OUTBOUND_WHATSAPP` | Must be `true` to send |
| `DRY_RUN` | When `true`, logs digest only — no HTTP send |

**Do not** enable outbound until you have confirmed the test number in `.env`.

---

## Webhook security

- Set `WEBHOOK_SECRET` and validate `X-Hub-Signature-256` for Meta POSTs (implement before production)
- Bind `BOT_HOST=127.0.0.1` — never `0.0.0.0` on untrusted networks without firewall
- Rotate `META_APP_SECRET` if leaked; never commit secrets

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Twilio 21608 | Recipient not joined sandbox |
| Meta 403 on webhook | Verify token mismatch |
| No messages sent | Check `DRY_RUN`, `ALLOW_OUTBOUND_WHATSAPP`, `WHATSAPP_TEST_NUMBER` |
| Auth errors | Run `device-access-check.ps1`; re-copy tokens from console |
