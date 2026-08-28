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

## Behavior when auth is missing

Script exits **0**, logs **blocked** to ACTION-LOG, prints one line — no push failure spam.

## Related

- [VSCODE-MANAGEMENT.md](./VSCODE-MANAGEMENT.md)
- [WSL-MANAGEMENT.md](./WSL-MANAGEMENT.md)