# Git diagnosis — 2026-08-28

## Symptoms
- Git commands and IDE Git UI hang on Windows for F: drive repos.
- Deep recursive filesystem scans under large trees (fun4kids, ai-workspace) exceed 30s+.

## Findings (auto-fix session)
| Check | Result |
|---|---|
| `.git/index.lock` (winners) | None present |
| Zombie `git.exe` (~2:38 PM) | 5 processes idle **>37 min** — killed |
| Stuck agent `Get-ChildItem -Recurse index.lock` | PID 57260 running **>45s** — stopped |
| `git status` ai-workspace | **0.58s** after fixes |
| `git fetch --dry-run` | **3.95s** (<15s timeout) |
| `gh` / GCM | `sync-gh-auth.ps1` OK — GCM + GH_TOKEN for oren-gcs |
| Submodule gitlinks | Mitigated: global `diff.ignoreSubmodules dirty`, `submodule.recurse false` |

## Root causes (likely)
1. **Orphaned git processes** from earlier hung operations block new git metadata work.
2. **Submodule / multi-root workspace** triggers many concurrent git scans (Cursor/VS Code).
3. **Broad recursive scans** on F: (locks, file search) amplify latency.

## Applied mitigations
- Local repo config: `core.longpaths`, `core.fsmonitor`, `status.submoduleSummary false`, `submodule.recurse false` on ai-workspace, doc-power-local-k8s, fun4kids.
- User env: `GIT_TERMINAL_PROMPT=0`.
- `.git/info/exclude` patterns for heavy dirs in ai-workspace.
- Workspace: `git.autorefresh false`, `git.maxConcurrentProcesses 2`, `git.enableSmartCommit true`.
- Hooks: `install-auto-push-hooks.ps1`; background worker + `sync-gh-auth` before push.

## Device-access pattern (add)
When git hangs >30s on F:, before escalating: (1) check/kill idle git >5m, (2) avoid full-tree `Get-ChildItem -Recurse` on winner roots, (3) run targeted lock removal on known `.git/index.lock` paths only, (4) apply submodule ignore settings, (5) `sync-gh-auth.ps1`.

## Resolution status
**Partial** — CLI git is fast again; confirm Cursor Source Control no longer spins after reload with new workspace settings.
