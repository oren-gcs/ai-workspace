# Connected Platforms — Grok Social Bot

Index of platform setup guides. **None are live until you complete OAuth and set tokens in `local/.env`.**

| Platform | Type | Enable flag | Setup guide |
|----------|------|-------------|-------------|
| WhatsApp (Meta) | Notifications | `WHATSAPP_PROVIDER=meta` | [CONFIG-META-WHATSAPP-FACEBOOK.md](CONFIG-META-WHATSAPP-FACEBOOK.md) |
| WhatsApp (Twilio) | Notifications | `WHATSAPP_PROVIDER=twilio` | [WHATSAPP-SETUP.md](WHATSAPP-SETUP.md) |
| Facebook Page | Social mentions | `ENABLE_FACEBOOK=true` | [CONFIG-META-WHATSAPP-FACEBOOK.md](CONFIG-META-WHATSAPP-FACEBOOK.md) |
| X (Twitter) | Social mentions | `ENABLE_TWITTER=true` | [SOCIAL-ACCOUNTS.md](SOCIAL-ACCOUNTS.md) |
| LinkedIn | Social mentions | `ENABLE_LINKEDIN=true` | [SOCIAL-ACCOUNTS.md](SOCIAL-ACCOUNTS.md) |
| Instagram | Social mentions | `ENABLE_INSTAGRAM=true` | [SOCIAL-ACCOUNTS.md](SOCIAL-ACCOUNTS.md) |
| **Spotify** | Listening activity | `ENABLE_SPOTIFY=true` | [SPOTIFY-SETUP.md](SPOTIFY-SETUP.md) |

---

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│ SocialConnector │     │ SpotifyConnector │     │ GrokClient  │
│ (mentions)      │────▶│ (listening)      │────▶│ summarize   │
└─────────────────┘     └──────────────────┘     └──────┬──────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │ WhatsApp digest │
                                               └─────────────────┘
```

- **Social connectors** (`local/src/social/`): Facebook, Twitter, LinkedIn, Instagram
- **Spotify connector** (`local/src/connectors/spotify.ts`): listening history, not mentions
- **Webhook server** (`127.0.0.1:3847`): Meta WhatsApp webhook + Spotify OAuth callback

---

## Chrome profile

| Platform | Recommended login |
|----------|-------------------|
| Meta / Facebook / Instagram | Work — `oren@gcs-tech.org` |
| Spotify | Personal (listening digest) or work — see [SPOTIFY-SETUP.md](SPOTIFY-SETUP.md) |
| X / LinkedIn | Work brand account |

Mapping: `F:\ai-workspace\config\accounts-connection-map.json` → `grok_bot`

---

## Quick start checklist

- [ ] `XAI_API_KEY` in `.env`
- [ ] Pick WhatsApp provider (Twilio sandbox or Meta)
- [ ] Enable at least one content source (social and/or Spotify)
- [ ] Complete OAuth per platform guide
- [ ] `npm run dry-run` in `local/`
- [ ] Update `accounts-connection-map.json` status (no secrets)

---

## Env template

Copy `local/.env.example` → `local/.env`. Never commit `.env`.
