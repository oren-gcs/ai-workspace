import http from "node:http";
import { loadConfig, validateConfig } from "./config.js";
import { formatMetaConfigStatus, getMetaConfigStatus } from "./meta/config-status.js";
import { BotScheduler } from "./scheduler.js";

function startWebhookServer(
  host: string,
  port: number,
  webhookPath: string,
  verifyToken: string
): http.Server {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url ?? "/", `http://${host}:${port}`);

    if (url.pathname === webhookPath && req.method === "GET") {
      const mode = url.searchParams.get("hub.mode");
      const token = url.searchParams.get("hub.verify_token");
      const challenge = url.searchParams.get("hub.challenge");
      if (mode === "subscribe" && token === verifyToken && challenge) {
        res.writeHead(200, { "Content-Type": "text/plain" });
        res.end(challenge);
        return;
      }
      res.writeHead(403);
      res.end("Forbidden");
      return;
    }

    if (url.pathname === webhookPath && req.method === "POST") {
      let body = "";
      req.on("data", (chunk) => {
        body += chunk;
      });
      req.on("end", () => {
        console.log("[webhook] incoming POST (stub handler)", body.slice(0, 200));
        res.writeHead(200);
        res.end("OK");
      });
      return;
    }

    if (url.pathname === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok", service: "grok-social-bot" }));
      return;
    }

    res.writeHead(404);
    res.end("Not found");
  });

  server.listen(port, host, () => {
    console.log(`[server] webhook ${host}:${port}${webhookPath} | health /health`);
  });

  return server;
}

async function main(): Promise<void> {
  const config = loadConfig();
  const issues = validateConfig(config);

  console.log("=== Grok Social Bot ===");
  console.log("Status: scaffold — connections require user OAuth/API setup");
  for (const issue of issues) {
    console.log(`  • ${issue}`);
  }

  const metaStatus = getMetaConfigStatus(config);
  for (const line of formatMetaConfigStatus(metaStatus)) {
    console.log(line);
  }

  if (config.server.publicWebhookBaseUrl) {
    console.log(
      `Meta webhook URL: ${config.server.publicWebhookBaseUrl.replace(/\/$/, "")}${config.server.webhookPath}`
    );
  } else if (config.whatsapp.provider === "meta") {
    console.log(
      `Local webhook (tunnel required): http://${config.server.host}:${config.server.port}${config.server.webhookPath}`
    );
  }

  const server = startWebhookServer(
    config.server.host,
    config.server.port,
    config.server.webhookPath,
    config.whatsapp.meta.verifyToken
  );

  const scheduler = new BotScheduler(config);
  scheduler.start();

  const shutdown = () => {
    console.log("\n[shutdown]");
    scheduler.stop();
    server.close();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main().catch((err) => {
  console.error("[fatal]", err);
  process.exit(1);
});
