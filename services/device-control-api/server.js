/**
 * device-control-api — Local HTTP control plane for device-control.ps1
 * Binds 127.0.0.1:3920 only.
 */
import http from "node:http";
import { spawn } from "node:child_process";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..", "..");
const RUNNING_FILE = join(ROOT, "config", "running-services.json");
const DEVICE_CONTROL = join(ROOT, "scripts", "device-control.ps1");
const HOST = "127.0.0.1";
const PORT = 3920;

function runDeviceControl(args) {
  return new Promise((resolve, reject) => {
    const ps = spawn(
      "powershell",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", DEVICE_CONTROL, ...args],
      { cwd: ROOT, windowsHide: true }
    );
    let stdout = "";
    let stderr = "";
    ps.stdout.on("data", (d) => (stdout += d));
    ps.stderr.on("data", (d) => (stderr += d));
    ps.on("close", (code) => {
      resolve({ code, stdout, stderr });
    });
    ps.on("error", reject);
  });
}

function readRunningServices() {
  if (!existsSync(RUNNING_FILE)) {
    return { generatedAt: null, services: {} };
  }
  return JSON.parse(readFileSync(RUNNING_FILE, "utf8"));
}

function json(res, status, body) {
  const payload = JSON.stringify(body, null, 2);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(payload),
  });
  res.end(payload);
}

async function handleStatus() {
  await runDeviceControl(["status", "-Json"]);
  const running = readRunningServices();
  let statusJson = {};
  try {
    const result = await runDeviceControl(["status", "-Json"]);
    statusJson = JSON.parse(result.stdout);
  } catch {
    statusJson = { apps: [], git: {}, error: "status parse failed" };
  }
  return { ...statusJson, runningServicesFile: running };
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${HOST}:${PORT}`);
  const path = url.pathname;

  try {
    if (req.method === "GET" && path === "/status") {
      const body = await handleStatus();
      return json(res, 200, body);
    }

    const startMatch = path.match(/^\/start\/([a-z0-9-]+)$/);
    if (req.method === "POST" && startMatch) {
      const id = startMatch[1];
      const result = await runDeviceControl(["start", id]);
      const running = readRunningServices();
      return json(res, 200, { action: "start", id, exitCode: result.code, running });
    }

    const stopMatch = path.match(/^\/stop\/([a-z0-9-]+)$/);
    if (req.method === "POST" && stopMatch) {
      const id = stopMatch[1];
      const result = await runDeviceControl(["stop", id]);
      const running = readRunningServices();
      return json(res, 200, { action: "stop", id, exitCode: result.code, running });
    }

    if (req.method === "GET" && path === "/health") {
      return json(res, 200, { ok: true, bind: `${HOST}:${PORT}` });
    }

    json(res, 404, { error: "not found", routes: ["GET /status", "GET /health", "POST /start/:id", "POST /stop/:id"] });
  } catch (err) {
    json(res, 500, { error: String(err.message || err) });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`device-control-api listening on http://${HOST}:${PORT}`);
});
