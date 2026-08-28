# WSL Management Guide

**Purpose:** Use WSL as the preferred shell for git, Docker, gcloud, Firebase, and gh on the F: drive portfolio. This guide complements [VSCODE-MANAGEMENT.md](./VSCODE-MANAGEMENT.md) and the separate [ACTION-LOG](../ACTION-LOG.md).

**Last updated:** 2026-08-28

---

## Access F: from WSL

Windows `F:\` maps to `/mnt/f/` in WSL.

| Windows path | WSL path |
|---|---|
| `F:\ai-workspace` | `/mnt/f/ai-workspace` |
| `F:\DevSecOps\projects\doc-power-local-k8s` | `/mnt/f/DevSecOps/projects/doc-power-local-k8s` |
| `F:\fun4kids` | `/mnt/f/fun4kids` |
| `F:\DevSecOps\projects\my_study_portal` | `/mnt/f/DevSecOps/projects/my_study_portal` |
| `F:\DevSecOps\projects\GCS-tech` | `/mnt/f/DevSecOps/projects/GCS-tech` |
| `F:\_archive\_inventory` | `/mnt/f/_archive/_inventory` |

**Performance note:** Cross-filesystem I/O (`/mnt/f/` vs native ext4 under `~/`) is slower. Keep heavy `node_modules` builds inside WSL home when possible; project source on F: is fine for day-to-day work.

---

## Default distro

Current setup (verify with `wsl -l -v`):

- **Default:** Ubuntu-24.04 (WSL 2)
- **Also installed:** Ubuntu, docker-desktop (Docker Desktop integration distro)

Set default if needed:

```powershell
wsl --set-default Ubuntu-24.04
```

---

## Node / npm: WSL vs Windows

| Tool | Recommended location | Why |
|---|---|---|
| **Node.js / npm** | WSL (Ubuntu) | Matches Linux CI, avoids path and line-ending friction |
| **ProjectAgent (`lib/agent-class`)** | Either; prefer WSL for consistency | Requires `npm install` in that directory |
| **Cursor IDE** | Windows host | Opens workspace; integrated terminal can be WSL profile |

Install Node in WSL (one-time):

```bash
# Ubuntu 24.04 — use NodeSource or nvm
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
node -v && npm -v
```

Run agent-class from WSL:

```bash
cd /mnt/f/ai-workspace/lib/agent-class
npm install
export CURSOR_API_KEY="cursor_..."   # from Cursor Dashboard → Integrations
npm run list
npm run pm -- doc-power --dry-run "Review backlog"
```

---

## GitHub CLI (`gh`) — WSL vs Windows

**Problem:** Cursor agent shells and user terminals do not always share credentials. `gh auth status` in one environment may show "not logged in" while another is authenticated.

### Recommended approach

1. **Pick one primary environment** for gh — WSL Ubuntu-24.04 is recommended.
2. Authenticate **in the terminal you actually push from**:

```bash
gh auth login
# GitHub.com → HTTPS → Login with browser → authorize oren-gcs
gh auth setup-git
gh auth status
```

3. **Windows gh (optional):** If you also use PowerShell for git, run `gh auth login` separately in PowerShell, or rely on Git Credential Manager (GCM) after WSL setup.

### Credential sharing notes

| Mechanism | WSL ↔ Windows sharing |
|---|---|
| `gh` token (`~/.config/gh/`) | **Not shared** — separate per OS environment |
| Git Credential Manager (Windows) | Can serve HTTPS for Windows git; WSL may use its own credential helper |
| `GH_TOKEN` env var | Works in any shell if exported in that session |
| SSH keys | Can share if key lives on a mounted path and permissions are correct |

**Rule:** Before any push, run `gh auth status` in the **same terminal profile** you will use for `git push`. Log the result in [ACTION-LOG](../ACTION-LOG.md).

### Two-account caution

Portfolio uses **oren-gcs** (primary) and possibly **gilboacloud**. Verify active account before push:

```bash
gh auth status
git config user.email   # should match intended account
```

---

## Docker — Docker Desktop WSL2 backend

Docker Desktop is installed with WSL2 integration (`docker-desktop` distro).

1. **Docker Desktop → Settings → Resources → WSL Integration**
   - Enable integration for **Ubuntu-24.04** (and Ubuntu if used).
2. Verify from WSL:

```bash
docker version
docker compose version
cd /mnt/f/DevSecOps/projects/doc-power-local-k8s
docker compose config --quiet && echo "compose OK"
```

3. **doc-power compose** runs from project root:

```bash
cd /mnt/f/DevSecOps/projects/doc-power-local-k8s
docker compose up -d        # start
docker compose down         # stop
docker compose logs -f api-gateway   # tail one service
```

Use VS Code tasks (see `.vscode/tasks.json`) or the Docker extension when you prefer GUI over CLI.

---

## gcloud and Firebase from WSL

### gcloud

Install Google Cloud SDK in WSL (one-time):

```bash
# See https://cloud.google.com/sdk/docs/install#linux
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-cli/install.sh
gcloud init
gcloud auth list
```

Credentials live in WSL `~/.config/gcloud/`. Not automatically shared with Windows gcloud.

### Firebase

```bash
npm install -g firebase-tools
firebase login
cd /mnt/f/fun4kids   # example
firebase projects:list
```

Copy ai-workspace account template (never commit secrets):

```bash
cp /mnt/f/ai-workspace/config/google-accounts.json.template \
   /mnt/f/ai-workspace/config/google-accounts.json
# Edit locally; file is gitignored
```

---

## When to use WSL vs PowerShell in VS Code

| Task | Terminal | Reason |
|---|---|---|
| `git push`, `gh pr create` | **WSL** (user-controlled auth) | Consistent Linux git + gh; avoids agent credential isolation |
| `docker compose` for doc-power | **WSL** | Native Docker Desktop WSL2 socket |
| `gcloud`, `firebase` | **WSL** | SDK paths and creds stay in one place |
| Windows-only tools (Hyper-V, some installers) | **PowerShell** | Native Windows |
| Quick file ops on F: | Either | PowerShell is fine for read-only checks |
| Cursor agent runs | Windows (Cursor host) | Agent uses Windows shell unless configured otherwise; **you** push from WSL |

**Integrated terminal profiles** are preconfigured in `ai-workspace.code-workspace`:
- **PowerShell** (default on Windows)
- **WSL Ubuntu** → `wsl -d Ubuntu-24.04`

Switch profile: Terminal dropdown → **Select Default Profile**, or open a new terminal with the `+` dropdown.

---

## Open workspace from WSL

```bash
# Ensure VS Code / Cursor CLI is on PATH in WSL (code or cursor)
code /mnt/f/ai-workspace/ai-workspace.code-workspace
# or
cursor /mnt/f/ai-workspace/ai-workspace.code-workspace
```

From Windows Explorer: double-click `F:\ai-workspace\ai-workspace.code-workspace`.

From PowerShell:

```powershell
code F:\ai-workspace\ai-workspace.code-workspace
```

---

## Quick health check

Run after setup or when auth behaves unexpectedly:

```bash
# In WSL
echo "=== WSL ===" && uname -a
echo "=== gh ===" && gh auth status
echo "=== git ===" && git config user.name && git config user.email
echo "=== docker ===" && docker info --format '{{.ServerVersion}}' 2>/dev/null || echo "docker not ready"
echo "=== node ===" && node -v 2>/dev/null || echo "node not installed in WSL"
ls /mnt/f/ai-workspace/ai-workspace.code-workspace && echo "workspace file OK"
```

Record outcomes in [ACTION-LOG](../ACTION-LOG.md).
