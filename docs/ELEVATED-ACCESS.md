# Elevated access on LEGION-LAP (Windows)

## When elevation is needed

- **ACL hardening / deny entries** on files (e.g. credentials quarantined with explicit `(N)` deny ACEs on `Authenticated Users`, `Users`, `SYSTEM`)
- **takeown / icacls** changes that require administrator token
- **Machine-wide installs** (optional components, drivers, some Docker/WSL edge cases)
- **Scheduled tasks** that run with `HighestAvailable` or under `SYSTEM` (see `register-auto-push-schedule.ps1` — current `ai-workspace-auto-push` runs without admin)

Cursor agents and normal integrated terminals run **medium integrity (non-elevated)** even when your account is in `BUILTIN\Administrators`. UAC cannot be bypassed by the agent.

## How to run elevated scripts from VS Code / Cursor

1. Open **PowerShell** or **Terminal** outside the agent, or use **Run as Administrator** on PowerShell.
2. From an elevated prompt:
   ```powershell
   Set-Location F:\ai-workspace
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\elevated-quarantine-credentials.ps1
   ```
3. From a **non-elevated** prompt (triggers UAC — you must click **Yes**):
   ```powershell
   Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "F:\ai-workspace\scripts\elevated-quarantine-credentials.ps1"' -Wait
   ```

**Right-click:** `F:\ai-workspace\scripts\elevated-quarantine-credentials.ps1` → **Run with PowerShell** does **not** elevate; use **Run as administrator** on the shell first.

## Credentials quarantine one-liner (elevated)

After UAC approval, the maintained script clears deny ACEs, takes ownership, and moves the file:

```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "F:\ai-workspace\scripts\elevated-quarantine-credentials.ps1"' -Wait
```

Target layout: `F:\_archive\secrets-quarantine\gcs-tech-su_credentials-YYYY-MM-DD.csv`

Last run log (no file contents): `F:\ai-workspace\logs\elevated-quarantine-last.log`

## GH_TOKEN vs `gh auth` (not elevation)

GitHub push/auth failures are usually **expired or missing tokens**, not missing admin rights.

- Prefer: `gh auth login -h github.com -p https` (Windows) then verify with `gh auth status`
- CI/scripts: set `GH_TOKEN` to a PAT with repo scope — do **not** commit tokens or paste them in ACTION-LOG
- Elevation does **not** fix `Repository not found` / HTTP 401 from GitHub

## Limits

- **UAC** requires a human **Yes** on `RunAs`; agents cannot click it for you.
- Do **not** disable UAC or weaken default security permanently.
- Do **not** log credential file contents — only paths and outcomes.

## Related

- Workspace rule: quarantine path `F:\_archive\secrets-quarantine\`
- Script: `F:\ai-workspace\scripts\elevated-quarantine-credentials.ps1`
- Diagnostic helper: `F:\ai-workspace\scripts\elevated-quarantine-diag.ps1`
