# Grok Social Bot

Managed agent-company project for a **Grok-powered social monitoring bot** with **WhatsApp digest notifications**.

**Status:** Scaffold only — no live OAuth or API connections until you complete setup.

## Paths

| Item | Path |
|------|------|
| Agent workspace | `F:\ai-workspace\projects\grok-social-bot` |
| Runnable code | `F:\ai-workspace\projects\grok-social-bot\local` |
| Logs | `F:\ai-workspace\logs\grok-bot\` |
| Session script | `F:\ai-workspace\scripts\start-grok-bot-session.ps1` |

## Quick start

1. Copy `local/.env.example` → `local/.env` and fill keys (see docs below).
2. `npm install` in `local/`.
3. Start session:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\start-grok-bot-session.ps1
   ```
   Or VS Code: **Tasks → Run Task → Start Grok social bot session**.

## What you must configure

| Service | Env vars | Doc |
|---------|----------|-----|
| xAI Grok | `XAI_API_KEY` | https://console.x.ai/ |
| WhatsApp (pick one) | Meta or Twilio vars | [docs/WHATSAPP-SETUP.md](docs/WHATSAPP-SETUP.md) |
| Social (enable per platform) | `TWITTER_*`, `LINKEDIN_*`, etc. | [docs/SOCIAL-ACCOUNTS.md](docs/SOCIAL-ACCOUNTS.md) |
| Safety | `WHATSAPP_TEST_NUMBER`, `ALLOW_OUTBOUND_WHATSAPP=false` | Required before real sends |

## Dedicated Cursor / VS Code session

Open a separate window focused on this bot:

```powershell
code --new-window F:\ai-workspace\projects\grok-social-bot
```

Or add to multi-root workspace: `F:\ai-workspace\ai-workspace.code-workspace`.

See [AGENTS.md](AGENTS.md) for team roles and session workflow.

## Prior art

Optional Grok reviewer stub: `F:\ai-workspace\config\grok-reviewer.json.template`
