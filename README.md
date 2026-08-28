# AI Workspace — Multi-Agent Project Orchestration

**Root:** `F:\ai-workspace\`  
**Architecture:** `F:\_archive\_inventory\agent-company-architecture-2026-08-28.md`  
**Manifest:** `F:\_archive\_inventory\project-agents-manifest.json`

Each project under `projects/` is a **software company**: a PM agent coordinates Developer, DevOps, QA, Security, and Learning/Revenue roles. Code lives in `local/` (junction to F:\ winner). Claude history lives in `claude/` (pointers only).

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
```

## Projects (teams scaffolded)

| Slug | Local winner | Skill |
|------|--------------|-------|
| doc-power | `F:\DevSecOps\projects\doc-power-local-k8s` | doc-power-local-dev |
| fun4kids | `F:\fun4kids` | fun4kids-firebase |
| my-study-portal | `F:\DevSecOps\projects\my_study_portal` | my-study-portal |
| gcs-tech | `F:\DevSecOps\projects\GCS-tech` | gcs-tech-cordev |

## Legacy

`F:\DevSecOps\ai-workspace` — pre-migration GCS emulator lab (6 agents). New orchestration uses this tree.

## User setup required

- `CURSOR_API_KEY` for SDK runs
- `gh auth login` for git push workflows
- Google: copy `config/google-accounts.json.template` → `google-accounts.json`, configure gcloud/Firebase
- Optional: `XAI_API_KEY` for Grok reviewer (see `config/grok-reviewer.json.template`)

## Git and `local/` junctions

Each `projects/*/local/` path is a **Windows junction** to the canonical repo on `F:\` (see table above). Those targets are separate git repositories. In **this** repo, git records them as **gitlinks** (commit `160000`), not as copied files—clones get an empty `local/` folder unless you recreate the junction or add proper submodules later. Do not remove the junctions on disk to “fix” git; keep links intact and work in the winner paths for code changes.
