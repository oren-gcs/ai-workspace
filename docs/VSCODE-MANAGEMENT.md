# VS Code Management Runbook

**Purpose:** Daily workflow for managing the F: drive portfolio from VS Code / Cursor using the multi-root workspace. Operational actions are logged separately in [ACTION-LOG](../ACTION-LOG.md) — not in git commit messages alone.

**Workspace file:** `F:\ai-workspace\ai-workspace.code-workspace`  
**WSL details:** [WSL-MANAGEMENT.md](./WSL-MANAGEMENT.md)

---

## Open the workspace

### Windows

```powershell
code F:\ai-workspace\ai-workspace.code-workspace
# or Cursor:
cursor F:\ai-workspace\ai-workspace.code-workspace
```

Or: **File → Open Workspace from File…** → select `ai-workspace.code-workspace`.

### WSL

```bash
code /mnt/f/ai-workspace/ai-workspace.code-workspace
```

---

## Workspace roots

| Root name | Path | Role |
|---|---|---|
| ai-workspace (orchestration) | `F:\ai-workspace` | Agent framework, MCP registry, PM runs |
| doc-power-local-k8s | `F:\DevSecOps\projects\doc-power-local-k8s` | Primary SaaS / K8s winner |
| fun4kids | `F:\fun4kids` | Kids app (Firebase) |
| my-study-portal | `F:\DevSecOps\projects\my_study_portal` | Study portal (port **3007**) |
| GCS-tech (insight) | `F:\DevSecOps\projects\GCS-tech` | Insight dashboard |
| archive-inventory (read-only ref) | `F:\_archive\_inventory` | Dedup audits, merges, manifests |

---

## Recommended extensions

Installed via workspace recommendations (accept prompt on first open):

| Extension | ID | Use |
|---|---|---|
| Remote - WSL | `ms-vscode-remote.remote-wsl` | Edit and terminal in WSL |
| Docker | `ms-azuretools.vscode-docker` | Compose, containers, logs |
| GitHub Pull Requests | `github.vscode-pull-request-github` | PRs after gh auth |
| Firebase | `toba.vsfirestore` | fun4kids Firestore |
| Cloud Code | `googlecloudtools.cloudcode` | gcloud / K8s (optional) |

---

## Daily workflow

### 1. Start session

1. Open `ai-workspace.code-workspace`.
2. Open integrated terminal → select **WSL Ubuntu** profile for git/docker/gh work.
3. Optional: run task **gh: auth status (WSL)** (see Tasks below).
4. Check brain queue: `C:\Users\oren\.claude\brain\queue.json` or brain-dispatcher skill.

### 2. Pick a project root

Use the Explorer multi-root tree. Code edits happen in each project's **winner path** (not `ai-workspace/projects/*/claude/`).

For doc-power, the canonical path is `doc-power-local-k8s` root — not archived `doc-power` trees.

### 3. Work and commit

- Commit **code changes** in each project's own git repo.
- Log **operational actions** (auth, merges, infra moves) in [ACTION-LOG](../ACTION-LOG.md).

### 4. End session

- Note blockers in ACTION-LOG (e.g. push deferred pending `gh auth login`).
- Leave docker compose state documented if you started services.

---

## Integrated terminal profiles

Configured in `ai-workspace.code-workspace`:

| Profile | When to use |
|---|---|
| **PowerShell** | Default on Windows; quick checks, Windows-only tools |
| **WSL Ubuntu** | git push, gh, docker compose, gcloud, firebase |

Create additional profiles in **Terminal → Configure Terminal Settings** if needed (e.g. dedicated doc-power directory).

---

## Git push workflow

**Principle:** You control authentication in your terminal. Cursor agents may not see your `gh` credentials.

### doc-power-local-k8s

```bash
# WSL terminal
cd /mnt/f/DevSecOps/projects/doc-power-local-k8s
gh auth status                    # must show logged in as oren-gcs
git status
git log -1 --oneline              # e.g. a209e7a Cursor rules commit

# First-time remote (when auth ready):
gh repo create oren-gcs/doc-power-local-k8s --private --source=. --remote=origin --push

# Subsequent pushes:
git push -u origin master
```

Log push attempts and results in ACTION-LOG.

### ai-workspace

```bash
cd /mnt/f/ai-workspace
git status
git add -A && git commit -m "Describe change"
# After gh auth + remote configured:
git push -u origin master
```

### Other portfolio repos

| Project | Path | Notes |
|---|---|---|
| fun4kids | `/mnt/f/fun4kids` | Review dirty files before commit |
| GCS-tech | `/mnt/f/DevSecOps/projects/GCS-tech` | |
| my_study_portal | `/mnt/f/DevSecOps/projects/my_study_portal` | Serves on port 3007 |
| Gcs-CorDev | `/mnt/f/DevSecOps/projects/Gcs-CorDev` | |

---

## ProjectAgent runs

Location: `F:\ai-workspace\lib\agent-class`

### From WSL (recommended)

```bash
cd /mnt/f/ai-workspace/lib/agent-class
npm install
export CURSOR_API_KEY="cursor_..."
npm run list
npm run pm -- doc-power --dry-run "Summarize P0 blockers"
npm run pm -- doc-power "Task description"    # live SDK call
```

### From Windows PowerShell

```powershell
cd F:\ai-workspace\lib\agent-class
npm install
$env:CURSOR_API_KEY = "cursor_..."
npm run list
npm run pm -- doc-power --dry-run "Summarize P0 blockers"
```

Agent `cwd` for code changes should target project `local/` junctions under `ai-workspace/projects/{slug}/local/` → winner paths.

---

## VS Code tasks

Tasks live in `.vscode/tasks.json`. Run via **Terminal → Run Task…**

| Task | Action |
|---|---|
| **doc-power: docker compose up** | `docker compose up -d` in doc-power-local-k8s |
| **doc-power: docker compose down** | `docker compose down` |
| **doc-power: docker compose logs (follow)** | Tail all service logs |
| **agent-class: npm run list** | List projects and roles |
| **agent-class: pm dry-run (doc-power)** | PM dry-run, no API call |
| **gh: auth status (WSL)** | Check GitHub auth in WSL |
| **gh: auth status (PowerShell)** | Check GitHub auth in Windows |

Tasks use WSL where docker/gh consistency matters; agent-class tasks offer both WSL and PowerShell variants.

---

## Docker compose for doc-power

Prerequisites: Docker Desktop running, WSL integration enabled (see WSL guide).

```bash
cd /mnt/f/DevSecOps/projects/doc-power-local-k8s
cp .env.example .env    # if first run; edit locally, never commit secrets
docker compose up -d
```

API gateway default: `http://localhost:8000`

Stop:

```bash
docker compose down
```

Or use VS Code Docker extension: right-click `docker-compose.yml` → **Compose Up**.

---

## Remote - WSL workflow (optional)

For maximum Linux parity:

1. Install **Remote - WSL** extension.
2. Command Palette → **WSL: Open Folder in WSL** → `/mnt/f/ai-workspace`.
3. Open workspace file from inside WSL.

This keeps all terminals and tools native to Linux while editing F: files.

---

## Separation: git commits vs ACTION-LOG

| Record in git | Record in ACTION-LOG |
|---|---|
| Code, config templates, docs | Auth login/logout, merge decisions |
| Architecture markdown in repo | F: drive moves, archive operations |
| `.gitignore` updates | Push blocked / succeeded, remote creation |
| | gh account verification, audit runs |

See [ACTION-LOG](../ACTION-LOG.md) for entry template and convention.

---

## Auto-push to GitHub

See [AUTO-PUSH.md](./AUTO-PUSH.md) for GH_TOKEN, hooks, scheduled tasks, and repo list.
