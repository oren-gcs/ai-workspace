# Brain v2 — Cursor-evolved layer

**Created:** 2026-08-30  
**Purpose:** Extend the Claude brain (`C:\Users\oren\.claude\brain\`) with Cursor session learnings, device-control integration, and agent-company orchestration — without replacing the original store.

## Architecture

```
Claude brain (canonical, append-only graph)
    C:\Users\oren\.claude\brain\
         │
         │  bridge: RESUME.md, queue sync, knowledge-graph append
         ▼
Brain v2 (Cursor-evolved layer)
    F:\ai-workspace\brain-v2\
         │
         ├── session-learnings.json   ← distilled from ACTION-LOG
         ├── integrations/            ← maps to skills, device-control, agents
         └── automations/             ← Cursor automation drafts
```

**Rule:** Never delete or rewrite Claude brain originals. Brain v2 syncs *into* the graph; it does not fork it.

## Read order (session start)

1. `C:\Users\oren\.claude\brain\RESUME.md` — live handoff (includes Cursor evolution section)
2. `brain-v2/RESUME.md` — Cursor-specific state overlay
3. `open-loops.json` — unfinished threads (check `stale` flag)
4. `session-learnings.json` — distilled decisions from recent sessions
5. `integrations/` — how brain connects to device-control, skills, agent company

## Key paths

| What | Path |
|------|------|
| Claude brain (read/write graph) | `C:\Users\oren\.claude\brain\` |
| Brain v2 (this tree) | `F:\ai-workspace\brain-v2\` |
| Agent company root | `F:\ai-workspace\` |
| Device control hub | `F:\ai-workspace\scripts\device-control.ps1` |
| Project manifest | `F:\_archive\_inventory\project-agents-manifest.json` |
| Evolution doc | `F:\ai-workspace\projects\brain\BRAIN-EVOLUTION-2026-08-30.md` |

## Post-session ingest

```powershell
F:\ai-workspace\scripts\brain-ingest-session.ps1
```

## Workspace

`F:\ai-workspace\workspaces\brain-evolution.code-workspace`
