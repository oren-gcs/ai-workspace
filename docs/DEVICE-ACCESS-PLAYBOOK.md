# Device Access Playbook

**Purpose:** Operational reference for resolving device, app, and access blockers across the F: drive portfolio. Mirrors the global Cursor skill `device-access-resolver`.

**Skill path:** `C:\Users\oren\.cursor\skills\device-access-resolver\SKILL.md`  
**Diagnostic:** `F:\ai-workspace\scripts\device-access-check.ps1`  
**GitHub sync:** `F:\ai-workspace\scripts\sync-gh-auth.ps1`  
**Action log:** `F:\ai-workspace\ACTION-LOG.md`

---

## When to use

Invoke this playbook (or the skill) whenever an agent or script hits:

- GitHub auth / push failures
- Permission denied / ACL deny ACEs
- Path not found across PowerShell, Git Bash, or WSL
- gcloud / firebase / ADC expiry
- Docker compose or port conflicts
- Chrome profile mismatch during OAuth

**Do not** use for application logic bugs or cloud IAM changes requiring org admin.

---

## Protocol

```
1. Detect   — classify blocker type
2. Diagnose — device-access-check.ps1 + ACTION-LOG history
3. Fix      — section below for blocker type
4. Verify   — re-run failing command in same shell
5. Log      — append ACTION-LOG.md (no secrets)
6. Update   — extend skill/playbook if new pattern
```

Agents must complete steps 1–4 before reporting blocked to the user.

---

## Quick diagnostic

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\device-access-check.ps1
```

JSON output:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\device-access-check.ps1 -Json
```

---

## GitHub access

### Separate credential stores

| Store | Used by |
|---|---|
| `gh` CLI (`%APPDATA%\GitHub CLI\` or WSL `~/.config/gh/`) | `gh`, git after setup-git |
| Git Credential Manager (Windows Credential Manager) | Windows git, VS Code |
| GitHub Desktop | Desktop app only |
| VS Code GitHub extension | PR extension only |
| `GH_TOKEN` user env | Scripts, Cursor agents |

These **do not auto-sync**. Wiring `gh` from GCM:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\sync-gh-auth.ps1
```

### GH_TOKEN (recommended for agents)

```powershell
[System.Environment]::SetEnvironmentVariable("GH_TOKEN", "PASTE_TOKEN", "User")
# Restart terminal / Cursor
$env:GH_TOKEN = [System.Environment]::GetEnvironmentVariable("GH_TOKEN","User")
gh auth setup-git
gh api user -q .login
```

See [AUTO-PUSH.md](./AUTO-PUSH.md) for full auto-push workflow.

### Path forms for git operations

| Shell | Example |
|---|---|
| PowerShell | `F:\ai-workspace` |
| Git Bash | `/f/ai-workspace` |
| WSL | `/mnt/f/ai-workspace` |

### WSL gh

```bash
which gh          # ~/bin/gh on Ubuntu installs
gh auth status
gh auth login     # separate from Windows
```

### Auto-push

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\auto-push.ps1
```

### Post-commit hooks

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\ai-workspace\scripts\install-auto-push-hooks.ps1
```

---

## Elevation / UAC

Agents run at medium integrity. UAC requires human approval — cannot be bypassed.

**Elevation needed for:** deny ACE removal, `takeown`, credential quarantine moves.

```powershell
Start-Process powershell -Verb RunAs -ArgumentList `
  '-NoProfile -ExecutionPolicy Bypass -File "F:\ai-workspace\scripts\elevated-quarantine-credentials.ps1"' -Wait
```

**Deny ACE removal:**
```powershell
icacls "F:\path\to\file" /remove:d "Authenticated Users"
icacls "F:\path\to\file" /remove:d "Users"
```

See [ELEVATED-ACCESS.md](./ELEVATED-ACCESS.md).

**GitHub HTTP 401 is not elevation** — fix auth, not UAC.

---

## Path matrix

| Context | F: example |
|---|---|
| PowerShell / CMD | `F:\ai-workspace` |
| Git Bash | `/f/ai-workspace` |
| WSL | `/mnt/f/ai-workspace` |

Normalize in scripts: `($path -replace '/', '\')` in PowerShell.

---

## Google / cloud reauth

Account map: `F:\ai-workspace\config\accounts-connection-map.json`  
Primary: **oren@gcs-tech.org** / **oren-gcs**

| Tool | Command |
|---|---|
| gcloud | `gcloud auth login` |
| ADC | `gcloud auth application-default login` |
| Firebase | `firebase login --reauth` |
| AWS | `aws sso login` (gcs-tech easy-run) |

Use Chrome **work profile** (oren@gcs-tech.org) for OAuth.

---

## Chrome profiles

- **Work:** oren@gcs-tech.org — GCP, Firebase, oren-gcs GitHub
- **Personal:** separate — avoid gilboacloud / oren-gcs confusion

Ensure correct profile is active when browser OAuth opens.

---

## Docker / local services

### doc-power

```powershell
cd F:\DevSecOps\projects\doc-power-local-k8s
docker compose up -d
```

Health: `http://localhost:3000` → 200.

### Port :9090 conflict

```powershell
docker ps --filter "publish=9090"
```

Stop conflicting `prometheus` container or adjust compose bind.

### WSL Docker

Docker Desktop → Settings → WSL Integration → enable Ubuntu-24.04.

---

## Credential quarantine

**Path:** `F:\_archive\secrets-quarantine\`

1. Diagnose: `elevated-quarantine-diag.ps1`
2. Move (elevated): `elevated-quarantine-credentials.ps1`
3. Log path + outcome only — never file contents

Never commit `*credentials*.csv` or `.env` with API keys.

---

## Per-project integration

Each project under `F:\ai-workspace\projects\*/agents\team.yaml` lists:

```yaml
skills: [device-access-resolver, <project-skill>]
```

PM agents run device-access-resolver before declaring P0 blockers.

---

## Related docs

- [AUTO-PUSH.md](./AUTO-PUSH.md)
- [ELEVATED-ACCESS.md](./ELEVATED-ACCESS.md)
- [WSL-MANAGEMENT.md](./WSL-MANAGEMENT.md)
- [VSCODE-MANAGEMENT.md](./VSCODE-MANAGEMENT.md)
- [ACTION-LOG.md](../ACTION-LOG.md)
