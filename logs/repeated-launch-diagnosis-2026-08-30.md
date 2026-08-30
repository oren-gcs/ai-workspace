# Repeated app launch diagnosis — 2026-08-30

**Host:** LEGION-LAP (Windows)  
**Investigator:** cursor-agent (command subagent)  
**Symptom:** VS Code, browsers, Docker/npm/MCP stacks feel like they keep opening or re-launching.

## Executive summary

| Finding | Severity | Opens UI? |
|---------|----------|-----------|
| **`start-all-local.ps1` (legacy default)** opened up to **6 VS Code windows + browser tabs** per run unless `-SkipOpen` | **Root cause** | Yes |
| **Cursor agents / subagents** re-invoking `start-all-local.ps1` and MCP scripts during device ops | Contributing | Depends on flags |
| **`ai-workspace-git-background-worker`** Task Scheduler job | Benign | No (git fetch/push only) |
| **`ai-workspace-auto-push`** daily 9:00 | Benign | No |
| **Scheduled `start-all-local`** | Not registered | N/A |
| **Docker restart loop** | Not observed (daemon down) | No |
| **Duplicate dev-server ports** | Not observed | No |
| **VS Code `runOn: folderOpen` tasks** | None in ai-workspace | No |

**Primary root cause:** A single **`start-all-local.ps1` run at 09:26** (logged in `logs/services-2026-08-30-run.md`) used the **old behavior** (`if (-not $SkipOpen)`), which launched **master.code-workspace**, **grok-social-bot**, **four symlink project folders**, and **default-browser URLs** for every service that responded on HTTP. That matches “apps opening over and over” when agents or humans re-run the script during a Cursor session.

**Fix applied (in repo, pending push):** UI is **opt-in** via `-OpenUI`. Background/agent/scheduled paths use **`-NoOpen`** (or omit `-OpenUI`). `smart-device-op.ps1 start` passes **`-NoOpen -SkipIfRunning`** by default.

---

## Process snapshot (2026-08-30 ~10:00)

| Process | Count | Notes |
|---------|------:|-------|
| `Code` | 52 | ~51 with empty `MainWindowTitle` (Electron renderer/utility), not 52 user windows |
| `Cursor` | 21 | IDE + extension hosts |
| `powershell` | 24+ | Agents, Task Scheduler, this diagnosis |
| `node` | 19 | vite, grok dry-run, MCP helpers, study portal |
| `docker` | 9 | Desktop present; **Linux engine not reachable** during check |

Recent `Code.exe` command lines showed many child processes spawned from one VS Code parent (`--type=utility` pattern), consistent with **one morning multi-window burst**, not a tight relaunch loop every minute.

---

## What fires how often

### Task Scheduler (ai-workspace)

| Task | Schedule | Last run (observed) | Action |
|------|----------|---------------------|--------|
| `ai-workspace-git-background-worker` | **Every 30 minutes** (3650-day repetition) | 2026-08-30 09:30, 10:03 | `git-background-worker.ps1` (hidden) |
| `ai-workspace-auto-push` | **Daily 09:00** | 2026-08-29 09:00 | `auto-push.ps1` |
| `ai-workspace-start-all-local` | — | **Not registered** | Optional; `register-start-all-local-schedule.ps1` would use `-NoOpen -SkipIfRunning` |

**Git worker today:** 9 log files under `logs/git-worker/worker-20260830-*.log` (30-min cadence + one extra run ~09:37). Each log: `Start (2 repos, timeout 120s)` → fetch/push only. **Does not start VS Code, browsers, or npm dev servers.**

### Manual / agent script runs (logs)

| Log | Runs today | Notes |
|-----|------------|-------|
| `logs/services-2026-08-30-run.md` | **1** header (`09:26:34`) | Legacy line: `VS Code: master.code-workspace, grok-social-bot, …` |
| `logs/mcps-2026-08-30.md` | **2** (`09:30`, `09:41`) | MCP bring-up; no browser/`code` |

### VS Code tasks (`F:\ai-workspace\.vscode\tasks.json`)

- No `runOptions.runOn` / folder-open automation.
- **“Start all local (idempotent, no UI)”** explicitly passes `-NoOpen -SkipIfRunning`.

---

## Network listeners (no duplicates on common ports)

| Port | PID role |
|------|----------|
| 3000 | doc-power / vite (single listener) |
| 3847 | grok-social-bot dry-run |
| 11434 | ollama |
| 11435 | ollama-mcp |

---

## Docker

- `docker ps` / `docker events` failed: **Docker Desktop Linux engine pipe not available** (Desktop may be installed via Run key but engine stopped).
- `start-all-local` logged `doc-power docker compose exit=1` on the 09:26 run — **no restart loop**, just failed compose.

---

## Cursor / MCP

- Multiple **MCP server spawn attempts** when Cursor reloads MCP config (stdio + HTTP) can look like “starting again”; `mcps-2026-08-30.md` shows only **two** explicit `start-all-mcps` runs.
- **Subagent fan-out:** `docs/AGENT-ROUTING.md` warns: do not spawn multiple subagents for “start all apps”. Parallel diagnosis shells still increase **powershell** noise but should not open VS Code if `-NoOpen` is used.

---

## Fixes applied in this change set

1. **`start-all-local.ps1`:** `$ShouldOpenUI = $OpenUI -and -not ($SkipOpen -or $NoOpen)` — default **no** VS Code/browser opens.
2. **`register-start-all-local-schedule.ps1`:** Scheduled invocation uses `-NoOpen -SkipIfRunning -WindowStyle Hidden`.
3. **`smart-device-op.ps1 start`:** Default **`-NoOpen`**; optional `-OpenUI` for deliberate desktop open.
4. **`.vscode/tasks.json`:** Task “Start all local (idempotent, no UI)” aligned with `-NoOpen`.

---

## Recommendations for oren

1. **Do not** run bare `start-all-local.ps1` when you only want services — use:
   ```powershell
   F:\ai-workspace\scripts\start-all-local.ps1 -SkipIfRunning -NoOpen
   ```
   Or: `smart-device-op.ps1 start` (same defaults after fix).

2. **To open workspaces intentionally (once):**
   ```powershell
   F:\ai-workspace\scripts\start-all-local.ps1 -SkipIfRunning -OpenUI
   ```

3. **Optional:** Close extra VS Code windows left from the 09:26 burst; expect many `Code.exe` processes to remain until you fully quit VS Code.

4. **Task Scheduler:** Keep `git-background-worker` if you want auto-fetch/push; it is **not** the UI spam source. Disable only if 30-min git activity is unwanted:
   ```powershell
   Disable-ScheduledTask -TaskName ai-workspace-git-background-worker
   ```

5. **Do not register** daily `start-all-local` scheduled task unless you want headless service refresh at 08:00 (it will not open UI with current registration script).

6. **Docker Desktop:** Start engine before doc-power compose or MCP_DOCKER; startup Run key launches UI, not always the engine.

---

## Evidence paths

- `F:\ai-workspace\logs\services-2026-08-30-run.md`
- `F:\ai-workspace\logs\mcps-2026-08-30.md`
- `F:\ai-workspace\logs\git-worker\worker-20260830-*.log`
- `F:\ai-workspace\scripts\start-all-local.ps1`
- `F:\ai-workspace\scripts\register-git-background-worker.ps1`
