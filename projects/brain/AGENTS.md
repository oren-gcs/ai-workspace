# Brain — Agent Company

**Charter:** Meta orchestration — queue dispatch, session continuity, cross-project coordination.

## Team

| Agent | Focus |
|-------|-------|
| **PM** | Queue drain, RESUME handoffs, P0 blocker coordination |
| **Developer** | queue.json, digests, dispatcher scripts |
| **DevOps** | BrainDashboard schtask, hourly automation |
| **QA** | Verify queue drain quality |
| **Security** | Credential leakage audit in brain artifacts |
| **Learning Coach** | Session continuity ↔ study goals |

## Paths

- **Brain root:** `C:\Users\oren\.claude\brain`
- **Orchestration:** `F:\ai-workspace\`
- **Team config:** `agents/team.yaml`

## Invoke PM

```powershell
cd F:\ai-workspace\lib\agent-class
npm run pm -- brain --dry-run "Drain queue and summarize blockers"
```
