# Agent routing — Cowork vs Cursor vs local scripts

**Goal:** Zero LLM cost for repeated device ops; escalate only when scripts cannot finish.

**Config:** `F:\ai-workspace\config\agent-routing.json`  
**Wrapper:** `F:\ai-workspace\scripts\smart-device-op.ps1`  
**Cowork guide:** `F:\ai-workspace\projects\brain\claude\COWORK-WHEN.md`

> Cursor model choice is **per chat / per subagent** — ai-workspace cannot set your global Cursor model. This doc and `agent-routing.json` are **recommendations** for humans and agents reading the repo.

---

## Decision tree (30 seconds)

```
User request
    │
    ├─ status / start / port check / git background sync?
    │       └─► smart-device-op.ps1 or direct PS1 (no LLM)
    │
    ├─ gh auth / elevation / docker / path / cloud reauth?
    │       └─► device-access-check.ps1 first
    │           └─ fail? Cursor agent + device-access-resolver skill
    │               model: composer-2.5-fast (shell-heavy)
    │
    ├─ code / refactor / tests / PR?
    │       └─► Cursor agent (default or thinking tier)
    │
    ├─ Claude Desktop UI / continue-stopped / Cowork push / Electron scroll?
    │       └─► Claude Desktop Cowork (requires app running)
    │
    └─ Meta/WhatsApp OAuth in browser?
            └─► User Chrome work profile OR Cowork computer-use
```

---

## Routing table

| Task type | Best tool | Model / tier | Why |
|-----------|-----------|--------------|-----|
| git status, background sync, port check | **Local scripts** (`status-all.ps1`, `git-background-worker.ps1`) | none | Zero LLM cost; deterministic |
| start local apps / MCPs / doc-power stack | **Local scripts** (`start-all-local.ps1`, `start-all-mcps.ps1`) | none | Already idempotent; skips occupied ports (`-SkipIfRunning`) |
| stop doc-power docker / read-only status | **Local scripts** (`smart-device-op stop` partial) | none | Scripted where safe |
| device access fix (gh, elevation, docker, paths) | **Cursor agent** + `device-access-resolver` skill | **composer-2.5-fast** | Shell-heavy; fast tier enough |
| read-only repo audit / find files | **Cursor subagent** `explore` | composer-2.5-fast | Read-only, bounded |
| multi-step implementation | **Cursor agent** or `generalPurpose` subagent | default / thinking | Quality over speed |
| CI failure on one PR | **Cursor subagent** `ci-investigator` | fast | Narrow scope |
| Claude Desktop UI, Cowork VM, browser scroll Electron | **Cowork** (Claude Desktop) | Cowork session | Cursor cannot control Claude app |
| continue-stopped Cowork sessions | **Cowork only** | — | Needs `session_info` + `computer-use` MCP |
| Push notifications (Cowork Desktop Commander) | **Cowork** | — | Cursor has no PushNotification MCP |
| Phone ntfy alerts | **Local script** `brain-notify.ps1` | none | Cowork optional fallback |
| Meta/WhatsApp OAuth browser | **User Chrome profile** OR Cowork computer-use | — | Interactive OAuth |
| Parallel project coordination | **COORDINATION.md** + `status-all.ps1` | fast agent for doc updates only | Scripts for truth; agent for prose |
| brain queue dispatch | **Cursor Automation** or `brain-dispatcher` skill | scheduled | Cowork hourly task ported |
| security scan review | **Cursor Automation** + `security-scan-review` skill | — | Reads JSON; no Cowork needed |

---

## Local script index (prefer these)

| Script | Purpose |
|--------|---------|
| `scripts/smart-device-op.ps1` | Router: status \| start \| stop \| push \| diagnose |
| `scripts/status-all.ps1` | Read-only ports + HTTP health (no starts) |
| `scripts/start-all-local.ps1` | Start apps, MCPs, doc-power; skip if port up (`-SkipIfRunning`); UI opt-in only (`-OpenUI`) |
| `scripts/start-all-mcps.ps1` | HTTP MCP services (ollama-mcp :11435, etc.) |
| `scripts/device-access-check.ps1` | gh, docker, paths, elevation diagnostic |
| `scripts/sync-gh-auth.ps1` | Wire gh from GCM / GH_TOKEN |
| `scripts/auto-push.ps1` | Push configured repos |
| `C:\Users\oren\.claude\brain\scripts\brain-notify.ps1` | ntfy phone alert (local) |

---

## Cursor subagent map

| Subagent type | Use when | Suggested model |
|---------------|----------|-----------------|
| `shell` | Device ops, bulk terminal | composer-2.5-fast |
| `explore` | Read-only codebase search | composer-2.5-fast |
| `generalPurpose` | Multi-step non-trivial work | default / thinking |
| `ci-investigator` | One failing PR check | composer-2.5-fast |

Do **not** spawn multiple subagents for "start all apps" — run `start-all-local.ps1 -SkipIfRunning -NoOpen` once.

---

## Cowork-only (do not port to Cursor)

From `claude-workflow-bridge` skill and brain RESUME:

- **continue-stopped** — needs Cowork `session_info` + `computer-use` on Claude Desktop
- **PushNotification** MCP (Desktop Commander alerts)
- **Automating Claude Desktop UI** (scroll, resume chat, usage-limit recovery)
- Cowork cloud sessions without local transcript

Cowork **requires Claude Desktop running** on legion-lap.

---

## Examples

### "Start all apps"

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\smart-device-op.ps1 start
# or directly:
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\start-all-local.ps1 -SkipIfRunning -NoOpen
```

**Do not** spawn five Cursor subagents to start fun4kids, study portal, GCS-tech, etc.

### "What's running?"

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\smart-device-op.ps1 status
```

### "Push failed with 401"

1. `device-access-check.ps1`
2. `sync-gh-auth.ps1`
3. If still failing → Cursor agent with `device-access-resolver` at **composer-2.5-fast**

### "Resume my stopped Claude chat"

→ Open **Claude Desktop Cowork**; Cursor cannot list Cowork sessions.

---

## Related docs

- `F:\ai-workspace\COORDINATION.md` — MCP registry, parallel apps
- `F:\ai-workspace\docs\DEVICE-ACCESS-PLAYBOOK.md`
- `C:\Users\oren\.cursor\skills\claude-workflow-bridge\SKILL.md`
- `C:\Users\oren\.cursor\skills\device-access-resolver\SKILL.md`
- `C:\Users\oren\.claude\brain\RESUME.md` — brain handoff, phone channel

