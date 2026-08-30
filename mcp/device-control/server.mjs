#!/usr/bin/env node
/**
 * device-control MCP stdio server — wraps device-control.ps1
 */
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";

const DEVICE_CONTROL = "F:\\ai-workspace\\scripts\\device-control.ps1";

function runPs(args) {
  return new Promise((resolve, reject) => {
    const ps = spawn(
      "powershell",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", DEVICE_CONTROL, ...args],
      { windowsHide: true }
    );
    let stdout = "";
    let stderr = "";
    ps.stdout.on("data", (d) => (stdout += d));
    ps.stderr.on("data", (d) => (stderr += d));
    ps.on("close", (code) => resolve({ code, stdout, stderr }));
    ps.on("error", reject);
  });
}

function send(msg) {
  process.stdout.write(JSON.stringify(msg) + "\n");
}

const tools = [
  {
    name: "device_status",
    description: "Get status of all registered apps, MCPs, docker, and git health",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "app_start",
    description: "Start a registered app by id (skip if already running by default)",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string", description: "App id from device-apps.json or 'all'" },
        force: { type: "boolean", description: "Force start even if running" },
      },
      required: ["id"],
    },
  },
  {
    name: "app_stop",
    description: "Gracefully stop a registered app by id",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string", description: "App id from device-apps.json or 'all'" },
      },
      required: ["id"],
    },
  },
];

async function handleTool(name, args) {
  if (name === "device_status") {
    const r = await runPs(["status", "-Json"]);
    return { content: [{ type: "text", text: r.stdout || r.stderr }] };
  }
  if (name === "app_start") {
    const psArgs = ["start", args.id];
    if (args.force) psArgs.push("-ForceStart");
    const r = await runPs(psArgs);
    return { content: [{ type: "text", text: r.stdout || r.stderr || `exit ${r.code}` }] };
  }
  if (name === "app_stop") {
    const r = await runPs(["stop", args.id]);
    return { content: [{ type: "text", text: r.stdout || r.stderr || `exit ${r.code}` }] };
  }
  throw new Error(`Unknown tool: ${name}`);
}

const rl = createInterface({ input: process.stdin, terminal: false });

rl.on("line", async (line) => {
  let req;
  try {
    req = JSON.parse(line);
  } catch {
    return;
  }

  const { id, method, params } = req;
  let result;

  try {
    if (method === "initialize") {
      result = {
        protocolVersion: "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: { name: "device-control", version: "1.0.0" },
      };
    } else if (method === "tools/list") {
      result = { tools };
    } else if (method === "tools/call") {
      result = await handleTool(params.name, params.arguments || {});
    } else if (method === "notifications/initialized" || method === "ping") {
      return;
    } else {
      throw new Error(`Unsupported method: ${method}`);
    }
    send({ jsonrpc: "2.0", id, result });
  } catch (err) {
    send({ jsonrpc: "2.0", id, error: { code: -32603, message: String(err.message || err) } });
  }
});
