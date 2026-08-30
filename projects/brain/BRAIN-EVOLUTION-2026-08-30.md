# Brain Evolution — 2026-08-30

**Author:** Cursor agent (brain-evolution session)  
**Scope:** Evolve Claude brain with Cursor/ai-workspace session work  
**Constraint:** Never delete `C:\Users\oren\.claude\brain\` — sync and bridge

---

## What brain already does well

### Durable context store

The Claude brain at `C:\Users\oren\.claude\brain\` is a proven cross-session memory system:

- **RESUME.md** — human-readable handoff; read first every session
- **queue.json** — execution queue with pending/history and blocker notes
- **open-loops.json** — nightly-derived unfinished threads with `cursor_action` hints
- **knowledge-graph.json** — append-only JSONL; rich entity/observation model
- **context.json** — disk-verified project registry with collision detection (157 roots)
- **inbox.md** — verbatim capture for ADHD-friendly tangents

### Tooling pipeline

| Script | Output | Value |
|--------|--------|-------|
| `build-context.mjs` | context.json | Collision-safe project identity |
| `route-inbox.mjs` | routed.json | Evidence-based inbox routing |
| `dedupe-by-content.mjs` | dedupe.json | SHA-1 duplication at any depth |
| `score-projects.mjs` | quality.json | 100-pt quality scoring |
| `mine-transcripts.mjs` | digests/ | Local Claude Code transcript mining |
| `mine-all-chats.mjs` | thought-map | Cursor + Gemini chat mining |

### Brain MCP server

Nine tools with **correlation**, not just listing:

- `brain_status` — flags stale open issues, loops with nothing queued, blocked-on-Oren items
- Live read/write to same store the dashboard uses (port 7717)
- Pull-based — removes up-to-60-minute cron latency when session is open

### Phone + Gemini channel (2026-08-28)

- ntfy alerts, Phone Link SMS capture, nightly consolidation at 04:10 local
- Gemini Takeout import path ready
- 329 sessions mined into thought-map

### Scheduled agents

Hourly dispatcher, nightly consolidation, CKA study nudges, IT health alerts — all documented in `agents.json`.

---

## Gaps found vs session solutions

| Gap in Claude brain | Session solution (Cursor/ai-workspace) | Status |
|---------------------|----------------------------------------|--------|
| Cowork sessions leave no local transcript | `brain-ingest-session.ps1` + `session-learnings.json` | **New in brain-v2** |
| Brain MCP has no device operations | `device-control.ps1` hub + planned device-tools MCP wire | **Hub live; MCP wire pending** |
| No Cursor-specific RESUME overlay | `F:\ai-workspace\brain-v2\RESUME.md` | **New** |
| Agent company not in graph | 7+ teams in manifest; nodes appended to graph | **Synced** |
| Git auth opaque to agents | `sync-gh-auth.ps1` GCM→GH_TOKEN bridge | **Working** |
| Git hangs from validate-drawio hook | Hook disabled; bash cleanup in worker | **Resolved** |
| Credentials on F: drive | Elevated quarantine to secrets-quarantine | **Resolved** |
| Winner paths stale in loops | F: dedup 2026-08-24; loops marked stale | **Updated** |
| start-all scripts fragmented | device-control hub (CLI + API + MCP) | **Live** |
| Earn-money priorities implicit | P1 doc-power, P2 fun4kids, P3 CKA encoded | **New** |
| Grok bot not in brain | Scaffold + integration doc | **Documented** |
| Cursor Automation for dispatcher | Draft JSON in config/automations/ | **Draft ready** |
| Chrome profile → account map | accounts-connection-map.json | **Documented** |

---

## v2 architecture proposal

```
┌─────────────────────────────────────────────────────────────┐
│                    Session entry points                      │
│  Claude Desktop │ Cursor IDE │ Phone (ntfy) │ Dashboard    │
└────────┬──────────────┬──────────────┬──────────────┬───────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
┌────────────────────────────────────────────────────────────┐
│              C:\Users\oren\.claude\brain\ (canonical)       │
│  RESUME │ queue │ open-loops │ knowledge-graph (append)   │
│  context │ inbox │ digests │ brain MCP (stdio)            │
└────────────────────────┬───────────────────────────────────┘
                         │ bridge (append, sync)
                         ▼
┌────────────────────────────────────────────────────────────┐
│              F:\ai-workspace\brain-v2\ (Cursor layer)     │
│  RESUME overlay │ session-learnings │ integrations/        │
│  queue extensions │ automation drafts                       │
└────────────────────────┬───────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────────┐
│ device-      │ │ Agent        │ │ ACTION-LOG       │
│ control hub  │ │ company      │ │ (audit trail)    │
│ :3920 + MCP  │ │ 7+ teams     │ │                  │
└──────────────┘ └──────────────┘ └──────────────────┘
```

### Design principles

1. **Claude brain stays canonical** — graph is append-only; RESUME gets appended sections
2. **Brain-v2 is the Cursor lens** — session learnings, device-control wiring, agent company map
3. **Scripts before LLM** — device-control status before queue drain (zero cost)
4. **Earn-money filter** — queue drain prioritizes doc-power, fun4kids, CKA blockers
5. **No secrets in brain-v2** — accounts map has structure only; tokens stay in env/quarantine
6. **Post-session ingest** — `brain-ingest-session.ps1` closes the Cowork/Cursor transcript gap

### MCP orchestration (how they work together)

| MCP | Role in brain workflow |
|-----|------------------------|
| **brain-mcp** | Read queue/loops/graph; append decisions; `brain_status` correlation |
| **device-control** | Pre-flight: ports, docker, disk; start/stop earn-money apps |
| **ollama-mcp** | Cheap local inference for bulk mining/classification |
| **ProjectAgent** | PM runs per-project from team.yaml; not MCP but CLI orchestration |

**Recommended dispatcher flow:**

1. `device-control status` (or MCP equivalent)
2. `brain_status` — correlate blockers
3. Drain safe queue items
4. Append results to graph + ACTION-LOG
5. Update RESUME (both Claude and brain-v2)
6. Run `brain-ingest-session.ps1` if session produced ACTION-LOG entries

### Bridge documentation

| Direction | Mechanism |
|-----------|-----------|
| Claude → Cursor | Read canonical brain files; brain-v2 is overlay |
| Cursor → Claude | Append to knowledge-graph.json; append RESUME section |
| Sessions → brain-v2 | `brain-ingest-session.ps1` → session-learnings.json |
| Automations | Drafts in brain-v2/automations/ synced from config/automations/ |

### Next milestones

1. Wire device-tools into brain MCP (`to6vr41x`)
2. Activate Cursor Automation hourly dispatcher
3. Mine 15 priority Cowork sessions → project claude/ digests
4. Push doc-power-local-k8s to GitHub
5. Complete cka bridge auth+CORS (`brn8x2a1`)

---

## Files created/updated

| Deliverable | Path |
|-------------|------|
| Evolution doc | `F:\ai-workspace\projects\brain\BRAIN-EVOLUTION-2026-08-30.md` |
| Brain v2 root | `F:\ai-workspace\brain-v2\` |
| Ingest script | `F:\ai-workspace\scripts\brain-ingest-session.ps1` |
| Workspace | `F:\ai-workspace\workspaces\brain-evolution.code-workspace` |
| Claude RESUME | Appended Cursor evolution section |
| Claude open-loops | Resolved items marked stale |
| Claude queue | New items from backlog |
| Claude graph | New nodes appended |
| Team roles | IntegrationArchivist, DeviceOpsBridge added |
| Dispatcher skill | brain-v2 paths + device-control integration |
