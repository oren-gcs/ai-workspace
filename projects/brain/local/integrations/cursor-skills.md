# Cursor skills map

Brain project skills live in `C:\Users\oren\.cursor\skills\`.

| Skill | Path | brain-v2 usage |
|-------|------|----------------|
| brain-dispatcher | `brain-dispatcher\SKILL.md` | Queue drain, graph append, safety boundaries |
| brain-resume-protocol | `brain-resume-protocol\SKILL.md` | Session-start handoff |
| device-access-resolver | `device-access-resolver\SKILL.md` | Auth, paths, docker blockers |
| f-drive-project-map | `f-drive-project-map\SKILL.md` | Resolve winner paths |
| claude-workflow-bridge | `claude-workflow-bridge\SKILL.md` | Cowork vs Cursor routing |

## brain-v2 paths (skills updated 2026-08-30)

| Artifact | Primary (Cursor) | Canonical (Cowork) |
|----------|------------------|---------------------|
| RESUME | `F:\ai-workspace\projects\brain\local\RESUME.md` | `C:\Users\oren\.claude\brain\RESUME.md` |
| Queue | `F:\ai-workspace\projects\brain\local\queue.json` | `C:\Users\oren\.claude\brain\queue.json` |
| Open loops | `F:\ai-workspace\projects\brain\local\open-loops.json` | `C:\Users\oren\.claude\brain\open-loops.json` |
| Knowledge graph | both (append-only, sync) | both |

Run sync before dispatcher work if sessions ran in both Claude and Cursor.
