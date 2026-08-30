# MCP orchestration

1. **brain-mcp** — memory (queue, graph, loops)
2. **device-control MCP** — ops (start/stop apps)
3. **ProjectAgent CLI** — per-project PM runs

Flow: brain_status → device-control status → drain queue → graph append → brain-ingest-session
