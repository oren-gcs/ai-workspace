# brain-v2 — Cursor runtime layer

This folder is the **Cursor-evolved brain**. Claude Desktop owns the live Cowork brain at `C:\Users\oren\.claude\brain\`. This layer merges ai-workspace session work without replacing Claude originals.

## Sync

```powershell
# Pull Claude → local (default)
F:\ai-workspace\scripts\brain-sync.ps1

# Bidirectional merge (queue + open-loops only)
F:\ai-workspace\scripts\brain-sync.ps1 -Direction both

# Push local queue changes back to Claude
F:\ai-workspace\scripts\brain-sync.ps1 -Direction push
```

### What syncs

| File | Direction | Notes |
|------|-----------|-------|
| `queue.json` | both | Pending items merged by id; history appended |
| `open-loops.json` | both | Loops merged by text hash; stale flags preserved |
| `knowledge-graph.json` | pull only | Append-only from Claude; local appends pushed |
| `RESUME.md` | pull only | Claude is canonical for Cowork |
| `session-learnings.json` | local only | Never pushed to Claude |

### What never syncs

- Secrets, credentials, `.env` contents
- `digests/` (Claude-only mining output)
- Phone/ntfy config with topics

## After major Cursor sessions

```powershell
F:\ai-workspace\scripts\brain-ingest-session.ps1
```

Parses recent `ACTION-LOG.md` entries into `session-learnings.json`.

## Structure

```
local/
  RESUME.md              # Cursor session state (derived from Claude + sessions)
  queue.json             # Merged pending + history
  open-loops.json        # Updated blockers with cursor_action hints
  knowledge-graph.json   # JSONL entities (append-only)
  session-learnings.json # Distilled from ACTION-LOG + coordination
  integrations/          # Cross-system link docs
  automations/           # Pointers to config/automations/
```

## Read order (RESUME protocol)

1. `local/RESUME.md` (or Claude `RESUME.md` if sync is fresh)
2. `local/open-loops.json`
3. `C:\Users\oren\.claude\CLAUDE.md` (global contract)
4. Named project → `C:\Users\oren\.claude\brain\context.json`
