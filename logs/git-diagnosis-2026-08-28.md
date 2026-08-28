# Git Windows diagnosis — 2026-08-28 (LEGION-LAP)

**Actor:** cursor-agent (IT super-admin live diagnosis)  
**Prior fix commit:** `c6fcad1` (spawn-auto-push, git-background-worker, docs). Note: `99e980fc` not found in ai-workspace history.

## Symptom (user-reported)

Git on Windows still feels **stuck**: Cursor/VS Code Git activity spinner, slow `git status`/commit, machine sluggish during agent sessions. Not fully resolved after non-blocking hook work.

## Executive summary

| Finding | Severity | Status this run |
|---------|----------|-----------------|
| **128 hung `bash.exe`** running Cursor **deploy-on-aws** `validate-drawio.sh` (blocked on `cat` / stdin) | **P0** | **Stopped** via cleanup; script added |
| **Phantom gitlinks** (`projects/*/local/` mode 160000, no `.gitmodules`) | **P1** | **Removed from index** + `.gitignore` |
| Prior hook/worker fixes (`spawn-auto-push`, scheduled task) | — | **Verified applied** |
| `gh` not logged in in agent shell | P2 | Unchanged — run `gh auth login` in interactive session |
| Heavy `git add` on paths with `.venv` / `lib64` junction noise | P2 | Documented — use `git status -uno` / fix ignore rules for cka bootcamp venv |

## 1. Terminal state (Cursor terminals)

- `238214.txt`: `git add` + `git status` ran **~111s** (`running_for_ms: 111279`) — large tree + CRLF warnings under `projects/cka-ai-bootcamp/local/.venv`.
- No active hung `git` command in terminal metadata at diagnosis time.
- WSL apt/gh installs failed/hung (separate issue).

## 2. Processes (before cleanup)

```
bash.exe total: 130
bash with validate-drawio in CommandLine: 128
git.exe: 26 (mostly fsmonitor--daemon)
post-commit/spawn-auto-push bash: 0
```

Sample CommandLine:

`bash.exe --login -i ...\deploy-on-aws\...\scripts\validate-drawio.sh`

**Root cause (new vs c6fcad1):** Plugin PostToolUse hook spawns Git Bash per tool invocation; when stdin is not closed, `INPUT=$(cat)` blocks forever → process leak. This exhausts the machine and makes **all** Git operations feel stuck (not the post-commit hook).

## 3. Reproduce timings

| Test | Before / during | After fixes |
|------|-----------------|-------------|
| `git status -uno` (ai-workspace) | 2566 ms | **460–615 ms** |
| `git status` (full, sample) | 1546 ms (limited output) | — |
| `git fetch origin` (ai-workspace) | 3748 ms | — |
| `git status -uno` (doc-power-local-k8s) | 1157 ms | — |
| `git submodule status` | **fatal** (doc-power/local, fun4kids/local, …) **~6.4s** | **clean, ~0 output** |
| `spawn-auto-push.ps1 -OnlyPath F:\ai-workspace` | exit 0, ~5.7s | exit 0 |

## 4. Hooks

**ai-workspace** and **doc-power-local-k8s** `post-commit` both point to `F:/ai-workspace/scripts/spawn-auto-push.ps1` with detached `powershell.exe` — **correct**.

`Test-Path spawn-auto-push.ps1`: **True**

## 5. Git config (global)

- `core.longpaths=true`, `core.fsmonitor=true`, `core.preloadindex=true`
- `credential.https://github.com.helper` → `gh auth git-credential`
- `credential.msauthFlow=oauth`
- `status.submoduleSummary=false`
- `GIT_TERMINAL_PROMPT` User=**0**

## 6. GCM / credential

`git credential fill` in job: failed fast (~4s) with stdin/format issues in test harness — **no 10s+ hang**. Agent shell: `gh auth status` → **not logged in** (push from agents may still fail until interactive `gh auth login` or `GH_TOKEN`).

## 7. index.lock

None under ai-workspace or doc-power-local-k8s.

## 8. Submodule / junction

| Path | Type | Issue |
|------|------|-------|
| `projects/doc-power/local` | Junction → `F:\DevSecOps\projects\doc-power-local-k8s` | Was gitlink without `.gitmodules` |
| `projects/fun4kids/local` | gitlink | same |
| `projects/gcs-tech/local` | gitlink | same |
| `projects/my-study-portal/local` | gitlink | same |

**Fix:** `git rm --cached` + `.gitignore` entries (junctions remain on disk).

## 9. Scheduled tasks

| Task | Status | Last result |
|------|--------|-------------|
| `ai-workspace-git-background-worker` | Enabled, every 30 min | **0** at 15:00:01 |
| `ai-workspace-auto-push` | Enabled, daily 09:00 | **267011** (never successfully run) |

Worker log `worker-20260828-150006.log`: doc-power + ai-workspace **ok** (~25s total).

## 10. Fixes applied this run

1. **Killed 128** zombie `validate-drawio` bash processes (`bash` count 130 → 2).
2. Added `scripts/cleanup-stuck-git-bash.ps1`.
3. Removed phantom gitlinks for all `projects/*/local/` winner junctions.
4. Updated `docs/DEVICE-ACCESS-PLAYBOOK.md` and `device-access-resolver` SKILL.

## 11. What user should try next

1. **Reload Cursor window** after bash cleanup (Git UI should settle).
2. If `bash` count grows again: run `powershell -File F:\ai-workspace\scripts\cleanup-stuck-git-bash.ps1` and consider **disabling** deploy-on-aws `validate-drawio` PostToolUse hook in Cursor plugin settings.
3. Interactive terminal: `gh auth login -h github.com -p https` (agent shell had no gh session).
4. For large ai-workspace status: prefer `git status -uno`; add `projects/cka-ai-bootcamp/local/.venv/` to ignore if that tree should not be scanned.
5. Optional: fix scheduled task `ai-workspace-auto-push` logon result 267011 (run once manually as user oren).

## 12. Prior fix vs today

| c6fcad1 intent | Still valid? |
|----------------|--------------|
| Non-blocking post-commit | **Yes** — verified |
| Background worker | **Yes** — logs OK |
| GCM/oauth git config | **Yes** — present |
| **User still stuck** | **Different root cause:** plugin bash leak + phantom gitlinks (+ optional gh auth in agent shell) |

## 13. Follow-up (f09716b0 subagent)

| Item | Result |
|------|--------|
| Push `cdf7506` | Already on `origin/master` (ahead 0 after fetch) |
| Hook disabled | `C:\Users\oren\.cursor\plugins\cache\cursor-public\deploy-on-aws\7a17df718d26f07414b876e77a7480fa25089b08\hooks\hooks.json` — `PostToolUse` validate-drawio emptied; backup `hooks.json.disabled-validate-drawio-2026-08-28.bak` |
| Worker | `git-background-worker.ps1` now runs `cleanup-stuck-git-bash.ps1` each cycle |
| bash.exe count | 2 total, 0 validate-drawio (post-check) |

Restore hook: copy `hooks.json.disabled-validate-drawio-2026-08-28.bak` over `hooks.json` after plugin fix or uninstall deploy-on-aws.
