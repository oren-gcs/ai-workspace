# Device control integration

Brain dispatch coordinates with the device-control hub for app lifecycle.

## Entry points

```powershell
F:\ai-workspace\scripts\device-control.ps1 status
F:\ai-workspace\scripts\device-control.ps1 start all
F:\ai-workspace\scripts\device-control.ps1 start grok-bot
```

## Registry

`F:\ai-workspace\config\device-apps.json` — all registered apps with ports, start commands, workspace files.

## MCP

| Server | Transport | Start |
|--------|-----------|-------|
| device-control | stdio | Cursor `.cursor/mcp.json` |
| brain-mcp | stdio | Claude/Cursor spawns `server.mjs` |

## DeviceOpsBridge role

Team member responsible for:

1. Verifying app health before queue items that depend on running services
2. Updating `device-apps.json` when new projects register
3. Running `device-access-check.ps1` on blockers

## Pending integration

Queue item `to6vr41x`: wire `device-tools.mjs` into Claude brain MCP for `device_health`, `device_disk`, etc.
