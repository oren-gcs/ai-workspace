# PARALLEL-APPS.md — Which local apps can run simultaneously

Run **`F:\ai-workspace\scripts\status-all.ps1`** before **`start-all-local.ps1`** to see what is already up and avoid duplicate launches.

## Quick start

```powershell
# 1. Check what's running
F:\ai-workspace\scripts\status-all.ps1

# 2. Start only missing services (no VS Code, no browser tabs)
F:\ai-workspace\scripts\start-all-local.ps1 -SkipIfRunning

# 3. Open editors/browsers only when you want them
F:\ai-workspace\scripts\start-all-local.ps1 -OpenUI
```

Scheduled tasks and background workers should always use **`-NoOpen -SkipIfRunning`** (default for `register-start-all-local-schedule.ps1`).

## Port map

| Service | Port | Type | Parallel-safe |
|---------|------|------|---------------|
| doc-power frontend | 3000 | Docker | yes |
| doc-power Grafana | 3001 | Docker | yes |
| fun4kids dev | 3002 | Node | yes |
| GCS-tech dev | 3003 | Node | yes |
| Gcs-CorDev insights | 3004 | Node | yes |
| my_study_portal | 3007 | Node | yes |
| grok-social-bot | 3847 | Node | yes |
| doc-power API gateway | 8000 | Docker | yes |
| doc-power cAdvisor | 8080 | Docker | yes |
| doc-power admin (if up) | 8088 | Docker | yes |
| doc-power Postgres | 5432 | Docker | yes |
| Ollama daemon | 11434 | System | yes |
| ollama-mcp | 11435 | Node | yes |
| Vite (generic) | 5173 | Node | yes |

All listed services bind to **different ports** and can run at the same time on a typical dev machine.

## Typical parallel stacks

### Full local dev

- **doc-power** (Docker stack on 3000/8000/5432) + **ollama** (11434) + **ollama-mcp** (11435) + **grok** (3847)
- Add any Node dev server on 3002–3007 without conflict

### Kids app only

- **fun4kids** on 3002 — independent of doc-power

### Study portal only

- **my_study_portal** on 3007 — independent of other apps

## Memory guidance

| Stack | Rough RAM |
|-------|-----------|
| doc-power Docker (full) | 4–8 GB |
| Ollama + one model loaded | 4–12 GB |
| Each Node dev server | 200–600 MB |
| grok-social-bot | ~150 MB |

**Practical advice**

- On 16 GB RAM: doc-power + ollama + 1–2 Node apps is comfortable
- On 32 GB RAM: doc-power + ollama + grok + several Node apps is fine
- If Ollama is slow, unload unused models: `ollama ps`

## How idempotent start works

1. `get-running-services.ps1` probes ports, maps PIDs, checks Docker container names, and writes `config/running-services.json`
2. `start-all-local.ps1` / `start-all-mcps.ps1` read that registry before launching anything
3. If port is listening **and** health check passes → log **"already running — skip"**
4. If port is in use by an unknown process → **warn** and skip (use `-ForceRestart` to stop listener and relaunch)
5. VS Code and browser tabs open **only** with `-OpenUI`

## Registry file

`F:\ai-workspace\config\running-services.json` is updated automatically by probe/start scripts. Do not edit by hand.

## VS Code task

**Status: all local apps + MCPs** — runs `status-all.ps1` from the Command Palette → Tasks: Run Task.
