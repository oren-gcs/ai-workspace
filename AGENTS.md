# AI Workspace — Agent Instructions

## Device / access blockers

When blocked on device, app, or access issues (GitHub auth, permissions, paths, Docker, cloud reauth), **invoke the `device-access-resolver` skill** before reporting blocked to the user.

| Resource | Path |
|---|---|
| Skill | `C:\Users\oren\.cursor\skills\device-access-resolver\SKILL.md` |
| Playbook | [docs/DEVICE-ACCESS-PLAYBOOK.md](./docs/DEVICE-ACCESS-PLAYBOOK.md) |
| Diagnostic | `scripts/device-access-check.ps1` |
| GitHub sync | `scripts/sync-gh-auth.ps1` |
| Action log | [ACTION-LOG.md](./ACTION-LOG.md) |

**Protocol:** detect → diagnose → fix → verify → log ACTION-LOG → update skill if new pattern.

## Project teams

Each project under `projects/*/agents/team.yaml` includes `device-access-resolver` in its skills list. PM agents run the protocol for P0 unblockers (gh auth, docker, elevation).

## Related

- [README.md](./README.md) — workspace overview
- [docs/AUTO-PUSH.md](./docs/AUTO-PUSH.md) — GitHub push automation
- [docs/ELEVATED-ACCESS.md](./docs/ELEVATED-ACCESS.md) — UAC and quarantine
