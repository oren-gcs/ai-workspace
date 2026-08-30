# RESUME state — brain-v2 (Cursor layer)

**Last updated:** 2026-08-30  
**Canonical Cowork source:** `C:\Users\oren\.claude\brain\RESUME.md` (sync via `brain-sync.ps1`)

## Cursor/ai-workspace evolution 2026-08-30

Brain is now a **formal tier-1 agent-company project** under `F:\ai-workspace\projects\brain\`.

| Change | Path |
|--------|------|
| brain-v2 runtime | `local/` |
| Team roles expanded | `agents/team.yaml` |
| Claude↔Cursor sync | `scripts/brain-sync.ps1` |
| Session learnings | `local/session-learnings.json` |
| Evolution doc | `BRAIN-EVOLUTION-2026-08-30.md` |

## Where we left off

1. **Agent company operational** — 7+ project teams scaffolded; device-control hub live on :3920
2. **Grok social bot** — scaffold complete; OAuth/WhatsApp pending user setup
3. **Git fixes landed** — validate-drawio bash leak cleared; phantom gitlinks removed
4. **MCP batch** — ollama-mcp :11435, grok-bot :3847; MCP_DOCKER blocked until Docker Desktop starts

## Top blockers (verify live files)

| Blocker | Action |
|---------|--------|
| `gh auth` not in agent shell | `gh auth login -h github.com` in interactive terminal |
| Two GitHub accounts (oren-gcs vs gilboacloud) | Verify GCM credential before doc-power push |
| Docker vhdx on C: (~122 GB) | Docker Desktop → Settings → move to F:\DockerData |
| cka-ai-bootcamp bridge 0.0.0.0 | Bind 127.0.0.1, debug=False, add auth token |

## Earning-money priorities (P0 queue routing)

1. **doc-power** — git init done (665a7dd); remote push blocked on gh auth
2. **fun4kids** — 18 dirty files; Firebase/Capacitor winner at F:\fun4kids
3. **my-study-portal** — CKA exam Oct 23 2026; port 3007

## F:\ winner map (always resolve by absolute path)

| Name | Path |
|------|------|
| doc-power | `F:\DevSecOps\projects\doc-power-local-k8s` |
| kids app | `F:\fun4kids` |
| insight | `F:\DevSecOps\projects\GCS-tech` |
| cordev | `F:\DevSecOps\projects\Gcs-CorDev` |
| study portal | `F:\DevSecOps\projects\my_study_portal` |
| grok bot | `F:\ai-workspace\projects\grok-social-bot\local` |
| brain | `F:\ai-workspace\projects\brain\local` |

## Skills to load

- `brain-resume-protocol` — session start
- `brain-dispatcher` — queue work
- `device-access-resolver` — on auth/path/docker block
