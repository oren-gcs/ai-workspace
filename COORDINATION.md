# ai-workspace coordination

## MCP servers (local)

| Name | Transport | Bind | Start |
|------|-----------|------|-------|
| ollama-mcp | HTTP Streamable | 127.0.0.1:11435 | `F:\ai-workspace\scripts\start-all-mcps.ps1` |
| brain-mcp | stdio | n/a | Cursor/Claude spawns `server.mjs` |
| doc-power-ollama-agents | stdio | n/a | `.mcp.json` in doc-power-local-k8s |
| MCP_DOCKER | stdio | n/a | `docker mcp gateway run` (Docker Desktop required) |
| grok-social-bot | HTTP webhook | 127.0.0.1:3847 | `scripts/start-grok-bot-session.ps1` |

Registry: `F:\ai-workspace\mcp\registry.json`

Cursor template: `F:\ai-workspace\.cursor\mcp.json` (copy entries into user or project MCP settings).

Daily log: `F:\ai-workspace\logs\mcps-YYYY-MM-DD.md`
