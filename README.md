# AI Workspace — Multi-Agent Project Orchestration

**Root:** `F:\ai-workspace\`  
**Architecture:** `F:\_archive\_inventory\agent-company-architecture-2026-08-28.md`  
**Manifest:** `F:\_archive\_inventory\project-agents-manifest.json`

Each project under `projects/` is a **software company**: a PM agent coordinates Developer, DevOps, QA, Security, and Learning/Revenue roles. Code lives in `local/` (junction to F:\ winner). Claude history lives in `claude/` (pointers only).

---

## VS Code workspace (primary management surface)

Open the multi-root workspace for day-to-day work across the portfolio:

| Platform | Command |
|---|---|
| **Windows** | `code F:\ai-workspace\ai-workspace.code-workspace` |
| **WSL** | `code /mnt/f/ai-workspace/ai-workspace.code-workspace` |

**Workspace file:** [ai-workspace.code-workspace](./ai-workspace.code-workspace)  
Includes: ai-workspace, doc-power-local-k8s, fun4kids, my-study-portal, GCS-tech, archive inventory (read-only).

### Recommended extensions

Accept workspace recommendations on first open:

- **Remote - WSL** — terminal and tooling in Ubuntu
- **Docker** — doc-power compose
- **GitHub Pull Requests** — after `gh auth login`
- **Firebase** — fun4kids
- **Cloud Code** — gcloud/K8s (optional)

---

## Documentation

| Doc | Purpose |
|---|---|
| [docs/VSCODE-MANAGEMENT.md](./docs/VSCODE-MANAGEMENT.md) | Daily workflow, git push, tasks, terminal profiles |
| [docs/WSL-MANAGEMENT.md](./docs/WSL-MANAGEMENT.md) | `/mnt/f/` paths, gh/docker/gcloud from WSL |
| [ACTION-LOG.md](./ACTION-LOG.md) | **Operational audit trail** (separate from git commits) |

**Convention:** Code changes → project git commits. Merges, auth, infra moves, push blockers → append [ACTION-LOG.md](./ACTION-LOG.md).

---

## Quick start

```powershell
cd F:\ai-workspace\lib\agent-class
npm install
$env:CURSOR_API_KEY = "cursor_..."   # from Cursor Dashboard → Integrations

# List projects and roles
npm run list

# PM dry-run (no API call)
npm run pm -- doc-power --dry-run "Review backlog for P0 blockers"

# PM with Cursor SDK (requires API key)
npm run pm -- doc-power "Summarize open blockers from brain queue for doc-power"
```

From WSL, use `/mnt/f/ai-workspace/lib/agent-class` and `export CURSOR_API_KEY=...`.

### VS Code tasks

**Terminal → Run Task…** — docker compose up/down, agent-class list/dry-run, gh auth status. See [docs/VSCODE-MANAGEMENT.md](./docs/VSCODE-MANAGEMENT.md).

---

## Layout

```
projects/{slug}/
  claude/          # Brain digests, Cowork session refs (read-only)
  local/           # Junction → winner path on F:\
  agents/
    team.yaml      # Role → skill + MCP mapping
    pm-agent.md    # PM instructions
  AGENTS.md        # Team charter

lib/agent-class/   # ProjectAgent TypeScript (@cursor/sdk)
mcp/registry.json  # Shared MCP servers
config/            # resources.json, google-accounts template, grok stub
docs/              # WSL + VS Code management runbooks
.vscode/tasks.json # Docker, agent-class, gh status tasks
```

---

## Projects (teams scaffolded)

| Slug | Local winner | Skill |
|------|--------------|-------|
| doc-power | `F:\DevSecOps\projects\doc-power-local-k8s` | doc-power-local-dev |
| fun4kids | `F:\fun4kids` | fun4kids-firebase |
| my-study-portal | `F:\DevSecOps\projects\my_study_portal` | my-study-portal |
| gcs-tech | `F:\DevSecOps\projects\GCS-tech` | gcs-tech-cordev |

---

## Legacy

`F:\DevSecOps\ai-workspace` — pre-migration GCS emulator lab (6 agents). New orchestration uses this tree.

---

## User setup required

- `CURSOR_API_KEY` for SDK runs
- `gh auth login` in **WSL terminal you push from** (see [WSL-MANAGEMENT.md](./docs/WSL-MANAGEMENT.md))
- Google: copy `config/google-accounts.json.template` → `google-accounts.json`, configure gcloud/Firebase
- Optional: `XAI_API_KEY` for Grok reviewer (see `config/grok-reviewer.json.template`)
- Docker Desktop with WSL2 integration for doc-power compose

---

## Git

This repo tracks orchestration code and docs only — not winner project source trees (those have their own repos under workspace roots).

**Push blocker (2026-08-28):** `gh auth login` required before remote create/push. See [ACTION-LOG.md](./ACTION-LOG.md).
