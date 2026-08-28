# SecurityCenter — Agent Company

**Charter:** Windows PC security audit service with scheduled scans and Electron UI.

## Team

| Agent | Focus |
|-------|-------|
| **PM** | Scan automation, alert triage, schtasks reliability |
| **Developer** | Electron UI, scan integrations |
| **DevOps** | Windows schtasks, alert-thresholds.ps1 |
| **QA** | Scan output validation, threshold tests |
| **Security** | Scan policy, remediation guidance |
| **Learning Coach** | Windows hardening ↔ CKA security topics |

## Paths

- **Code:** `C:\Users\oren\cowork\SecurityCenter` (not on F: drive — no local junction)
- **Claude history:** `claude/README.md`
- **Team config:** `agents/team.yaml`

## Invoke PM

```powershell
cd F:\ai-workspace\lib\agent-class
npm run pm -- security-center --dry-run "Review daily scan automation"
```
