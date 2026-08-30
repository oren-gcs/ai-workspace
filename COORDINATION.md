# ai-workspace coordination

## Device Control Hub (primary entry point)

**Start here** for all local app/service/MCP control:

```powershell
F:\ai-workspace\scripts\device-control.ps1 status
F:\ai-workspace\scripts\device-control.ps1 apps
F:\ai-workspace\scripts\device-control.ps1 start all
```

| Layer | Location | Port |
|-------|----------|------|
| CLI | `scripts/device-control.ps1` | — |
| HTTP API | `services/device-control-api/` | **127.0.0.1:3920** |
| MCP | `mcp/device-control/server.mjs` | stdio |
| App registry | `config/device-apps.json` | — |
| Running state | `config/running-services.json` | — |

Full docs: [DEVICE-APP-CONTROL.md](docs/DEVICE-APP-CONTROL.md)

### Status bar quick reference

Run `device-control status` before starting work. Green = port listening or smoke OK.

| id | port |
|----|------|
| doc-power | 3000 |
| fun4kids | 3002 |
| gcs-tech | 3003 |
| cordev | 3004 |
| study-portal | 3007 |
| grok-bot | 3847 |
| ollama-mcp | 11435 |
| brain-dashboard | 7717 |

---

## Brain project (meta orchestration)

**Tier-1 meta project** — session memory, queue, RESUME protocol, earning priority routing.

| Item | Path |
|------|------|
| Project root | `F:\ai-workspace\projects\brain` |
| brain-v2 runtime | `F:\ai-workspace\projects\brain\local` |
| Claude brain | `C:\Users\oren\.claude\brain` |
| Workspace | `F:\ai-workspace\workspaces\brain.code-workspace` |
| Sync | `F:\ai-workspace\scripts\brain-sync.ps1` |

Open dedicated session:

```powershell
code --new-window F:\ai-workspace\workspaces\brain.code-workspace
```

Team roles: PM, IntegrationArchivist, DeviceOpsBridge, Dispatcher, LearningCoach, SecurityAuditor.

Evolution doc: `projects/brain/BRAIN-EVOLUTION-2026-08-30.md`

---

## MCP servers (local)

| Name | Transport | Bind | Start |
|------|-----------|------|-------|
| device-control | stdio | n/a | Cursor `.cursor/mcp.json` |
| ollama-mcp | HTTP Streamable | 127.0.0.1:11435 | `device-control start ollama-mcp` |
| brain-mcp | stdio | n/a | Cursor/Claude spawns `server.mjs` |
| doc-power-ollama-agents | stdio | n/a | `.mcp.json` in doc-power-local-k8s |
| MCP_DOCKER | stdio | n/a | `docker mcp gateway run` (Docker Desktop required) |
| grok-social-bot | HTTP webhook | 127.0.0.1:3847 | `device-control start grok-bot` |

Registry: `F:\ai-workspace\mcp\registry.json`

Cursor template: `F:\ai-workspace\.cursor\mcp.json` (copy entries into user or project MCP settings).

Daily log: `F:\ai-workspace\logs\mcps-YYYY-MM-DD.md`

## Legacy scripts (still valid)

| Script | Prefer instead |
|--------|----------------|
| `start-all-local.ps1` | `device-control start all` |
| `start-all-mcps.ps1` | `device-control start all` (includes MCP batch) |
| `status-all.ps1` | `device-control status` |

## VS Code tasks

Open `F:\ai-workspace\workspaces\master.code-workspace` → **Terminal → Run Task**:

- **Device Control: Status**
- **Device Control: Start All**
