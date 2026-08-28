import type { AppConfig } from "./config.js";
import { createSpotifyConnector } from "./connectors/spotify.js";
import { GrokClient } from "./grok-client.js";
import { createSocialConnectors, formatMention, type SocialMention } from "./social/index.js";
import { createWhatsAppNotifier } from "./whatsapp/index.js";

export class BotScheduler {
  private interval: ReturnType<typeof setInterval> | null = null;
  private lastPoll = new Date(Date.now() - 24 * 60 * 60 * 1000);

  constructor(private readonly config: AppConfig) {}

  async runCycle(): Promise<void> {
    const grok = new GrokClient(this.config.xai);
    const connectors = createSocialConnectors(this.config);
    const whatsapp = createWhatsAppNotifier(this.config);

    const spotify = createSpotifyConnector(this.config);
    const configured = connectors.filter((c) => c.isConfigured);
    console.log(
      `[cycle] social configured: ${configured.map((c) => c.platform).join(", ") || "none"} | ` +
        `spotify: ${spotify?.isConfigured ? "ready" : this.config.spotify.enabled ? "awaiting token" : "off"} | ` +
        `whatsapp: ${whatsapp.provider} (${whatsapp.isConfigured ? "ready" : "stub"}) | ` +
        `grok: ${grok.isConfigured ? "ready" : "missing XAI_API_KEY"} | ` +
        `dryRun: ${this.config.runner.dryRun}`
    );

    const allMentions: SocialMention[] = [];
    for (const connector of connectors) {
      const mentions = await connector.fetchRecentMentions(this.lastPoll);
      allMentions.push(...mentions);
    }
    this.lastPoll = new Date();

    const formatted = allMentions.map(formatMention);
    const spotifyLines = spotify ? await spotify.fetchDigestLines() : [];
    let digest: string;

    if (grok.isConfigured && (formatted.length > 0 || spotifyLines.length > 0)) {
      digest = await grok.summarizeDigest(formatted, spotifyLines);
    } else if (formatted.length > 0 || spotifyLines.length > 0) {
      const parts: string[] = [];
      if (formatted.length > 0) {
        parts.push(`Mentions (${formatted.length}):\n\n${formatted.join("\n\n")}`);
      }
      if (spotifyLines.length > 0) {
        parts.push(`Spotify (${spotifyLines.length}):\n\n${spotifyLines.join("\n")}`);
      }
      digest = parts.join("\n\n---\n\n");
    } else {
      digest =
        "Grok Social Bot: no new mentions or listening activity this cycle. (Enable platforms in .env after OAuth.)";
    }

    const result = await whatsapp.sendDigest(digest);
    console.log("[whatsapp]", JSON.stringify(result));

    if (this.config.runner.dryRun) {
      console.log("[digest preview]\n", digest.slice(0, 800));
    }
  }

  start(): void {
    const ms = this.config.runner.pollIntervalMs;
    console.log(`[scheduler] polling every ${ms}ms`);
    void this.runCycle();
    this.interval = setInterval(() => void this.runCycle(), ms);
  }

  stop(): void {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
  }
}
