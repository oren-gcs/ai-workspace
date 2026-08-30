# Grok social bot integration

Brain tracks grok-social-bot as an agent-company project with earning potential.

## Paths

| Item | Path |
|------|------|
| Project | `F:\ai-workspace\projects\grok-social-bot` |
| Runtime | `F:\ai-workspace\projects\grok-social-bot\local` |
| Session script | `F:\ai-workspace\scripts\start-grok-bot-session.ps1` |
| Logs | `F:\ai-workspace\logs\grok-bot\` |

## Device control

```powershell
F:\ai-workspace\scripts\device-control.ps1 start grok-bot
```

Port **3847**, health at `http://127.0.0.1:3847`.

## Setup blockers (open loop)

- `XAI_API_KEY` from https://console.x.ai/
- WhatsApp provider (Meta Cloud API or Twilio)
- Per-platform OAuth (LinkedIn, Twitter, etc.)

## Brain queue linkage

Social monitoring digests can be queued via brain MCP `brain_queue_add` for PM review before WhatsApp send.

## Never

Commit `.env`, OAuth tokens, or webhook secrets.
