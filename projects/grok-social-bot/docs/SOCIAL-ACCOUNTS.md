# Social Accounts — Grok Social Bot

**Honest status:** Social platforms are **stub connectors** until you create developer apps, complete OAuth, and set tokens in `local/.env`. **Never commit tokens.**

## Supported platforms (template)

| Platform | API | Enable flag | Key env vars |
|----------|-----|-------------|--------------|
| Facebook Page | Meta Graph API | `ENABLE_FACEBOOK=true` | `FACEBOOK_PAGE_ID`, `FACEBOOK_PAGE_ACCESS_TOKEN`, `META_APP_ID` |
| X (Twitter) | X API v2 | `ENABLE_TWITTER=true` | `TWITTER_BEARER_TOKEN`, OAuth 1.0a keys |
| LinkedIn | Marketing / Share API | `ENABLE_LINKEDIN=true` | `LINKEDIN_CLIENT_ID`, `LINKEDIN_ACCESS_TOKEN` |
| Instagram | Meta Graph API | `ENABLE_INSTAGRAM=true` | `INSTAGRAM_APP_ID`, `INSTAGRAM_ACCESS_TOKEN` |

Implementations live in `local/src/social/` — Facebook has a Graph API connector; others return empty arrays until OAuth is complete.

---

## Facebook Page (Meta Graph)

Shares the same Meta Developer app as WhatsApp. Full wizard: **[CONFIG-META-WHATSAPP-FACEBOOK.md](CONFIG-META-WHATSAPP-FACEBOOK.md)**.

1. https://developers.facebook.com/ (Chrome work profile `oren@gcs-tech.org`)
2. Same app as WhatsApp — add Page permissions
3. Generate Page access token with `pages_read_engagement`
4. `.env`:
   ```
   ENABLE_FACEBOOK=true
   FACEBOOK_PAGE_ID=
   FACEBOOK_PAGE_ACCESS_TOKEN=
   META_APP_ID=
   ```

Feed + tagged posts: Graph API `/{page-id}/feed` and `/{page-id}/tagged`.

---

## Chrome / Google account mapping

Use the **work lane** identity from `F:\ai-workspace\config\accounts-connection-map.json`:

| Context | Value |
|---------|-------|
| Primary email | `oren@gcs-tech.org` |
| GitHub | `oren-gcs` |
| Chrome profile | Work / GCS-tech profile (not personal Gmail) |

When creating OAuth apps, log into developer consoles with the profile that owns the brand/business you are monitoring.

### `grok_bot` section (accounts-connection-map)

Placeholder added under `connections` → `appId: grok_bot`. Update `status` after each OAuth completes.

---

## X (Twitter) / X API

1. Developer portal: https://developer.x.com/
2. Create project + app (Elevated access may be required for mentions)
3. Enable OAuth 2.0 or 1.0a depending on endpoints
4. Scopes needed (typical): `tweet.read`, `users.read`, offline access for refresh
5. Copy to `.env`:
   ```
   ENABLE_TWITTER=true
   TWITTER_API_KEY=
   TWITTER_API_SECRET=
   TWITTER_ACCESS_TOKEN=
   TWITTER_ACCESS_TOKEN_SECRET=
   TWITTER_BEARER_TOKEN=
   ```

Store refresh tokens in `.env` or Windows Credential Manager — **not** in git.

---

## LinkedIn

1. https://www.linkedin.com/developers/apps
2. Create app → associate with company page
3. Products: **Share on LinkedIn**, **Sign In with LinkedIn** (as needed)
4. Redirect URL for local OAuth: `http://127.0.0.1:3847/oauth/linkedin/callback` (implement callback before use)
5. `.env`:
   ```
   ENABLE_LINKEDIN=true
   LINKEDIN_CLIENT_ID=
   LINKEDIN_CLIENT_SECRET=
   LINKEDIN_ACCESS_TOKEN=
   ```

OAuth docs: https://learn.microsoft.com/en-us/linkedin/shared/authentication/authentication

---

## Instagram (Meta Graph)

Requires Facebook Developer app (can share with WhatsApp Meta app).

1. https://developers.facebook.com/
2. Add **Instagram Graph API** product
3. Connect Instagram Business/Creator account to Facebook Page
4. `.env`:
   ```
   ENABLE_INSTAGRAM=true
   INSTAGRAM_APP_ID=
   INSTAGRAM_APP_SECRET=
   INSTAGRAM_ACCESS_TOKEN=
   ```

Mentions/comments: Graph API `/{ig-user-id}/tags` and webhooks — implement after token available.

---

## Token storage (professional)

| Method | Use |
|--------|-----|
| `local/.env` | Dev only; gitignored |
| User env (`setx`) | CI/agents without file |
| Windows Credential Manager | Optional script storage |
| Secret manager (GCP/AWS) | Production |

**Never:** commit `.env`, paste tokens in ACTION-LOG, or store in `team.yaml`.

---

## OAuth flow checklist

- [ ] Pick platform(s) and create developer app
- [ ] Use Chrome work profile (`oren@gcs-tech.org`)
- [ ] Set redirect URI to `127.0.0.1` for local
- [ ] Complete browser consent
- [ ] Copy tokens to `.env`
- [ ] Set `ENABLE_<PLATFORM>=true`
- [ ] Restart bot session
- [ ] Update `accounts-connection-map.json` → `grok_bot.status`

---

## Monetization angle

- Brand mention alerts (B2B)
- Affiliate link mention tracking
- Competitor keyword monitoring
- Premium digest frequency tiers

Grok summarizes; WhatsApp delivers — product is the **alert pipeline**, not raw API access.
