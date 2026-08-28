# Grok Social Bot — Agent Company

**Charter:** Monitor social mentions, summarize via xAI Grok, deliver digests on WhatsApp. Learning + monetization (social listening SaaS, affiliate alerts, brand monitoring).

**Code:** `local/` — TypeScript runner. **No secrets in repo.**

## Team

| Agent | Role |
|-------|------|
| **ProjectManager** | Session cadence, monetization, unblock OAuth |
| **GrokOperator** | Prompts, Grok API usage, rate limits |
| **SocialConnector** | X/Twitter, LinkedIn, Instagram stubs — user enables platforms |
| **WhatsAppNotifier** | Meta Cloud API or Twilio — test number gate |
| **SecurityAuditor** | Webhook secrets, 127.0.0.1 bind, token storage |

## Open another session (dedicated bot window)

Run and manage the bot in a **separate** Cursor/VS Code session so it does not compete with other projects:

### Option A — New window (recommended)

```powershell
code --new-window F:\ai-workspace\projects\grok-social-bot
```

Then: **Terminal → Run Task → Start Grok social bot session**.

### Option B — Multi-root workspace

Add `projects/grok-social-bot` folder to `F:\ai-workspace\ai-workspace.code-workspace`, open that folder in the explorer, start the task from there.

### Option C — Background runner

```powershell
F:\ai-workspace\scripts\start-grok-bot-session.ps1
```

Logs: `F:\ai-workspace\logs\grok-bot\`.

## Device access

On auth/path/docker blockers, load skill `device-access-resolver` and run `device-access-check.ps1` before escalating.

Patterns for this project: `F:\ai-workspace\config\device-access-patterns.json` → `grok-social-bot`.

## Grok reviewer link

Optional second-opinion reviewer config (not required for bot runtime):

- Template: `F:\ai-workspace\config\grok-reviewer.json.template`
- Env: `XAI_API_KEY` (shared with bot)

## Never

- Commit `.env`, OAuth tokens, or webhook secrets
- Set `ALLOW_OUTBOUND_WHATSAPP=true` without `WHATSAPP_TEST_NUMBER` confirmed
- Claim social/WhatsApp are connected until user completes OAuth in browser
