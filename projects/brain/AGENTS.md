# Brain — Agent Company

**Charter:** Meta orchestration — session memory, queue dispatch, RESUME protocol, cross-project coordination, earning-money priority routing.

**Parent:** ai-workspace agent company. Brain is THE orchestration project.

## Team

| Agent | Focus |
|-------|-------|
| **ProjectManager** | Queue drain, RESUME handoffs, P0 blocker coordination, earning priority |
| **IntegrationArchivist** | Session artifact merge, knowledge graph hygiene, brain-sync |
| **DeviceOpsBridge** | device-control.ps1 hub, app registry, MCP lifecycle |
| **Dispatcher** | Hourly queue processing, Cursor Automation port |
| **LearningCoach** | RESUME ↔ study goals, CKA countdown |
| **SecurityAuditor** | Credential leakage audit in brain artifacts |

## Paths

| Layer | Path |
|-------|------|
| Project root | `F:\ai-workspace\projects\brain` |
| brain-v2 (Cursor layer) | `F:\ai-workspace\brain-v2` |
| Claude brain (canonical) | `C:\Users\oren\.claude\brain` |
| Team config | `agents/team.yaml` |
| Evolution doc | `BRAIN-EVOLUTION-2026-08-30.md` |

## Invoke PM

```powershell
cd F:\ai-workspace\lib\agent-class
npm run pm -- brain --dry-run "Drain queue and summarize blockers"
```

## Open dedicated session

```powershell
code --new-window F:\ai-workspace\workspaces\brain-evolution.code-workspace
```

## Sync Claude ↔ Cursor

```powershell
F:\ai-workspace\scripts\brain-sync.ps1
F:\ai-workspace\scripts\brain-ingest-session.ps1
```

## Skills

Load `brain-resume-protocol` at session start, then `brain-dispatcher` for queue work. On blockers: `device-access-resolver`.

## Never

- Delete Claude brain originals
- Commit secrets into brain artifacts
- Force push any winner repo
