# Auto-push — GitHub without manual diff-tab push

Push configured F: repos when local commits exist and GitHub auth is available. **Never force-pushes.** Operational runs append to [ACTION-LOG.md](../ACTION-LOG.md).

## Quick start

```powershell
# After GH_TOKEN is set (see below):
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\auto-push.ps1
```

WSL (requires `gh` in WSL and `GH_TOKEN` or `gh auth login` there):

```bash
bash /mnt/f/ai-workspace/scripts/auto-push.sh
```

## Config

Edit [config/auto-push-repos.json](../config/auto-push-repos.json). Each entry:

| Field | Meaning |
|---|---|
| `path` | Absolute repo path (forward slashes OK) |
| `remote` | `owner/repo` on GitHub |
| `branch` | Branch to push (e.g. `master`) |

**Optional repos** (add when remotes exist):

| Project | Path | Suggested remote |
|---|---|---|
| fun4kids | `F:/fun4kids` | `oren-gcs/fun4kids` |
| GCS-tech | `F:/DevSecOps/projects/GCS-tech` | `oren-gcs/GCS-tech` |
| Gcs-CorDev | `F:/DevSecOps/projects/Gcs-CorDev` | `oren-gcs/Gcs-CorDev` |
| my_study_portal | `F:/DevSecOps/projects/my_study_portal` | `oren-gcs/my_study_portal` |

If the GitHub repo does not exist yet and auth works, the script runs `gh repo create owner/repo --private` (no force push).

## GH_TOKEN (recommended for Cursor + agents)

Fine-grained PAT on **oren-gcs** with **Contents: Read and write** on target repos (or all repos you auto-push).

### Windows (user env — persists across reboots)

```powershell
[System.Environment]::SetEnvironmentVariable("GH_TOKEN", "ghp_YOUR_TOKEN_HERE", "User")
# New terminals / Cursor restart required
```

One-liner after you have the token:

```powershell
[System.Environment]::SetEnvironmentVariable("GH_TOKEN", "PASTE_TOKEN", "User")
```

### WSL

Add to `~/.bashrc` or `~/.profile`:

```bash
export GH_TOKEN="ghp_YOUR_TOKEN_HERE"
```

Optional: `gh auth setup-git` runs automatically when `GH_TOKEN` is set.

**Never** commit tokens. Keep `GH_TOKEN` in environment only.

### Verify

```powershell
$env:GH_TOKEN = [System.Environment]::GetEnvironmentVariable("GH_TOKEN","User")
gh api user -q .login
```

Cursor agents often do not see interactive `gh auth login`; **`GH_TOKEN` is the autonomy path**.

## VS Code tasks

From `ai-workspace` workspace: **Terminal → Run Task…**

- **Auto-push all repos (PowerShell)**
- **Auto-push all repos (WSL)**

## Post-commit hooks (optional)

Non-blocking background push after each commit on **doc-power** and **ai-workspace** only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\install-auto-push-hooks.ps1
```

Preview: add `-WhatIf`. Hooks live in each repo's `.git/hooks/post-commit` (not versioned).

## Scheduled task (Windows)

Register hourly run (interactive user; needs `GH_TOKEN` in user env):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\register-auto-push-schedule.ps1
```

Remove:

```powershell
Unregister-ScheduledTask -TaskName "ai-workspace-auto-push" -Confirm:$false
```


## Troubleshooting (Git stuck on Windows)

| Symptom | Fix |
|---|---|
| Commit hangs after message | Re-run `install-auto-push-hooks.ps1`; hook must call `spawn-auto-push.ps1` (detached), not wait on push |
| `git status` slow on ai-workspace | Submodule scan noise — `git status -uno` or `git config --global status.submoduleSummary false` |
| `lib64/` warning on F: | WSL junction; safe to ignore for parent-repo work |
| Agent hangs on credential prompt | User env `GIT_TERMINAL_PROMPT=0`; run `sync-gh-auth.ps1` before push |
| Many `git-bash.exe` shells | Close stale terminals; hooks are non-blocking — investigate extensions spawning bash |

### Background worker (all repos)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File F:\ai-workspace\scripts\git-background-worker.ps1
```

Logs: `F:\ai-workspace\logs\git-worker\`. Register every 30 minutes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\register-git-background-worker.ps1
```

VS Code: **Git background sync (all repos)** task.

## Behavior when auth is missing

Script exits **0**, logs **blocked** to ACTION-LOG, prints one line — no push failure spam.

## Related

- [VSCODE-MANAGEMENT.md](./VSCODE-MANAGEMENT.md)
- [WSL-MANAGEMENT.md](./WSL-MANAGEMENT.md)
## GCM / VS Code / GitHub Desktop alignment

Interactive sign-in in **VS Code** (Accounts → GitHub) or **Cursor** stores an OAuth token in **Git Credential Manager (GCM)**. That token works for `git push` and for `gh` when exposed as `GH_TOKEN`.

| Source | Path / check | credential found |
|---|---|---|
| GCM (primary) | `git-credential-manager github list` | yes when VS Code signed in |
| `gh` hosts file | `%USERPROFILE%\.config\gh\hosts.yml` | often empty while GCM has auth |
| GitHub Desktop | `%LOCALAPPDATA%\GitHubDesktop\` | not installed on this machine |
| WSL `gh` | `~/.config/gh/hosts.yml` | separate; may be empty |

### Sync script (agents + PowerShell)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\sync-gh-auth.ps1
```

- Reads `protocol=https` / `host=github.com` from GCM (never logs the token).
- Sets **`GH_TOKEN` for the current process** so `gh auth status` shows `Logged in … (GH_TOKEN)`.
- Optional `-PersistUserEnv` writes User-level `GH_TOKEN` (OAuth may rotate; prefer running the script per session).

`gh auth login --with-token` expects a **classic PAT (`ghp_`)**. GCM usually stores **OAuth (`gho_`)**, which is valid for API/git via `GH_TOKEN` but not for `--with-token` import.

### Git Bash (DevSecOps Git)

| Tool | Path |
|---|---|
| Git Bash | `F:\DevSecOps\GIT\Git\bin\bash.exe` |
| `gh` | `/c/Program Files/GitHub CLI/gh` (same as Windows) |
| GCM | bundled with Git for Windows (`credential.helper=manager` in `F:\DevSecOps\GIT\Git\etc\gitconfig`) |

In Git Bash, run the sync script via PowerShell or export `GH_TOKEN` after GCM login in Windows.

### Verify after sync

```powershell
. F:\ai-workspace\scripts\sync-gh-auth.ps1 -Quiet
gh auth status
git -C F:\ai-workspace ls-remote origin
```

