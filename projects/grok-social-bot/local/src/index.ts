import http from "node:http";

import type { AppConfig } from "./config.js";

import { loadConfig, validateConfig } from "./config.js";

import { consumePendingAuth, storePendingAuth } from "./connectors/oauth-pending.js";

import {

  buildSpotifyAuthUrl,

  exchangeCodeForTokens,

  generatePkce,

} from "./connectors/spotify-auth.js";

import { formatMetaConfigStatus, getMetaConfigStatus } from "./meta/config-status.js";

import { BotScheduler } from "./scheduler.js";



const SPOTIFY_CALLBACK_PATH = "/auth/spotify/callback";



function startWebhookServer(config: AppConfig): http.Server {

  const { host, port, webhookPath } = config.server;

  const verifyToken = config.whatsapp.meta.verifyToken;



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



    if (url.pathname === SPOTIFY_CALLBACK_PATH && req.method === "GET") {

      void handleSpotifyCallback(config, url, res);

      return;

    }



    if (url.pathname === "/auth/spotify/start" && req.method === "GET") {

      handleSpotifyStart(config, res);

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

    console.log(

      `[server] webhook ${host}:${port}${webhookPath} | spotify ${SPOTIFY_CALLBACK_PATH} | health /health`

    );

  });



  return server;

}



function handleSpotifyStart(config: AppConfig, res: http.ServerResponse): void {

  const { clientId, redirectUri } = config.spotify;

  if (!clientId) {

    res.writeHead(400, { "Content-Type": "text/plain" });

    res.end("SPOTIFY_CLIENT_ID not set in .env");

    return;

  }



  const pkce = generatePkce();

  storePendingAuth(pkce);

  const authUrl = buildSpotifyAuthUrl({

    clientId,

    redirectUri,

    codeChallenge: pkce.codeChallenge,

    state: pkce.state,

  });



  res.writeHead(302, { Location: authUrl });

  res.end();

}



async function handleSpotifyCallback(

  config: AppConfig,

  url: URL,

  res: http.ServerResponse

): Promise<void> {

  const error = url.searchParams.get("error");

  if (error) {

    res.writeHead(400, { "Content-Type": "text/plain" });

    res.end(`Spotify auth denied: ${error}`);

    return;

  }



  const code = url.searchParams.get("code");

  const state = url.searchParams.get("state");

  if (!code || !state) {

    res.writeHead(400, { "Content-Type": "text/plain" });

    res.end("Missing code or state");

    return;

  }



  const pkce = consumePendingAuth(state);

  if (!pkce) {

    res.writeHead(400, { "Content-Type": "text/plain" });

    res.end("Invalid or expired OAuth state — restart auth via scripts/spotify-auth.ps1");

    return;

  }



  const { clientId, clientSecret, redirectUri } = config.spotify;

  if (!clientId) {

    res.writeHead(500, { "Content-Type": "text/plain" });

    res.end("SPOTIFY_CLIENT_ID not configured");

    return;

  }



  try {

    const tokens = await exchangeCodeForTokens({

      clientId,

      clientSecret,

      code,

      redirectUri,

      codeVerifier: pkce.codeVerifier,

    });



    if (tokens.refresh_token) {
      console.log("[spotify] OAuth success — save SPOTIFY_REFRESH_TOKEN to local/.env (value not logged)");
    } else {
      console.log(
        "[spotify] OAuth success — no refresh_token in response; re-authorize with show_dialog if needed"
      );
    }

    const refreshHint = tokens.refresh_token
      ? `<p>Add this to <code>local/.env</code> (shown once — not stored in server logs):</p>
<pre>ENABLE_SPOTIFY=true
SPOTIFY_REFRESH_TOKEN=${tokens.refresh_token}</pre>`
      : `<p>No refresh token returned. Revoke app at spotify.com/account/apps and re-authorize.</p>`;

    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(`<!DOCTYPE html>
<html><body>
<h1>Spotify connected</h1>
${refreshHint}
<p>You can close this tab and restart the bot.</p>
</body></html>`);

  } catch (err) {

    const msg = err instanceof Error ? err.message : String(err);

    console.error("[spotify] token exchange failed:", msg);

    res.writeHead(500, { "Content-Type": "text/plain" });

    res.end(`Token exchange failed: ${msg}`);

  }

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



  if (config.spotify.enabled) {

    console.log(

      `Spotify OAuth: http://${config.server.host}:${config.server.port}/auth/spotify/start (or scripts/spotify-auth.ps1)`

    );

  }



  const server = startWebhookServer(config);



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


