# Brain — Meta Orchestration Project

**Slug:** `brain`  
**Owner:** gcs-tech.org / oren-gcs  
**Parent:** ai-workspace agent company (THE orchestration project)

Session memory, queue dispatch, RESUME protocol, cross-project coordination, and earning-money priority routing for all agent-company projects.

## Paths

| Item | Path |
|------|------|
| Project root | `F:\ai-workspace\projects\brain` |
| Cursor brain-v2 runtime | `F:\ai-workspace\projects\brain\local` |
| Claude brain (Cowork) | `C:\Users\oren\.claude\brain` |
| Team config | `agents\team.yaml` |
| Evolution doc | `BRAIN-EVOLUTION-2026-08-30.md` |
| Sync script | `F:\ai-workspace\scripts\brain-sync.ps1` |
| Session ingest | `F:\ai-workspace\scripts\brain-ingest-session.ps1` |

## Bridge: Claude ↔ Cursor

Claude Desktop owns the live Cowork brain (`C:\Users\oren\.claude\brain`). Cursor evolves a parallel layer in `local/` that merges session work from ai-workspace. **Neither replaces the other** — sync with `brain-sync.ps1`.

See [local/README.md](local/README.md) for sync rules.

## Open dedicated session

```powershell
code --new-window F:\ai-workspace\workspaces\brain.code-workspace
```

Evolution workspace (includes Claude brain read-only context):

```powershell
code --new-window F:\ai-workspace\workspaces\brain-evolution.code-workspace
```

## Quick start

1. Read [AGENTS.md](AGENTS.md) for team charter.
2. Run RESUME protocol: load skills `brain-resume-protocol` then `brain-dispatcher`.
3. Sync from Claude brain: `powershell -File F:\ai-workspace\scripts\brain-sync.ps1`
4. After major sessions: `powershell -File F:\ai-workspace\scripts\brain-ingest-session.ps1`

## Skills

| Skill | Purpose |
|-------|---------|
| `brain-dispatcher` | Queue drain, knowledge graph, safety boundaries |
| `brain-resume-protocol` | Session-start handoff |
| `device-access-resolver` | Auth, paths, docker blockers |

## Monetization

Brain enables all projects. Earning priorities routed through queue:

1. **doc-power** — SaaS document processing
2. **fun4kids** — Kids routine app subscriptions
3. **my-study-portal** — CKA/MLOps courseware (exam Oct 2026)

## Never

- Delete Claude brain originals
- Commit secrets into brain artifacts
- Force push any winner repo
