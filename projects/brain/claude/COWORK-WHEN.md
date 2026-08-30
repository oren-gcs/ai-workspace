# When to use Claude Desktop Cowork vs Cursor

**Default:** Stay in **Cursor** for code, scripts, and anything local scripts can handle.  
**Cowork:** Only when Cursor literally cannot reach the capability.

Cowork requires **Claude Desktop running** on legion-lap.

---

## Use Cowork

| Situation | Why Cursor fails |
|-----------|------------------|
| **continue-stopped** scheduled task | Needs Cowork `session_info` + `read_transcript` + `computer-use` on Claude Desktop |
| **PushNotification** (Desktop Commander) | No PushNotification MCP in Cursor |
| **Automate Claude Desktop UI** (scroll, click, resume chat) | Cursor cannot drive Electron Claude app |
| **Recover usage-limit / stopped Cowork sessions** | Session list is Cowork-only |
| **Cowork VM / remote device bridge** flows | Desktop Commander scope |

Local alternative for phone alerts: `C:\Users\oren\.claude\brain\scripts\brain-notify.ps1` (ntfy) — prefer script over Cowork.

---

## Stay in Cursor

| Situation | Tool |
|-----------|------|
| Start/status local apps | `smart-device-op.ps1` / `start-all-local.ps1` / `status-all.ps1` |
| gh auth, docker, paths, elevation | `device-access-check.ps1` → Cursor agent + `device-access-resolver` |
| Code, tests, PRs, refactors | Cursor agent (default/thinking model) |
| Brain queue dispatch | Cursor Automation + `brain-dispatcher` skill |
| Security scan review | Cursor Automation + `security-scan-review` skill |
| Read-only audit | Cursor `explore` subagent at composer-2.5-fast |

---

## OAuth / browser

| Flow | Recommendation |
|------|----------------|
| Meta / WhatsApp / GCP / GitHub OAuth | **User Chrome work profile** (oren@gcs-tech.org) — human in loop |
| Repeatable browser automation inside Claude | Cowork **computer-use** (one-time approval per task) |

---

## Quick examples

**"Start all dev servers"** → Cursor runs:

```powershell
F:\ai-workspace\scripts\start-all-local.ps1 -SkipIfRunning
```

Not Cowork. Not five subagents.

**"Resume my stopped Claude Cowork session from yesterday"** → Open **Claude Desktop**; Cowork only.

**"Send phone alert"** → `brain-notify.ps1` first; Cowork only if script fails.

---

## References

- `F:\ai-workspace\docs\AGENT-ROUTING.md`
- `C:\Users\oren\.cursor\skills\claude-workflow-bridge\SKILL.md`
- `C:\Users\oren\.claude\brain\RESUME.md`
- Cowork scheduled skills: `C:\Users\oren\Claude\Scheduled\`
