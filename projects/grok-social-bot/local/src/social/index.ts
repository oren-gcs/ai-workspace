import type { AppConfig } from "../config.js";
import { FacebookConnector } from "./facebook.js";
import type { SocialConnector, SocialMention } from "./types.js";
import { formatMention } from "./types.js";

export { FacebookConnector };
export { formatMention };
export type { SocialConnector, SocialMention };

export class TwitterConnector implements SocialConnector {
  readonly platform = "twitter";

  constructor(private readonly config: AppConfig["social"]["twitter"]) {}

  get isConfigured(): boolean {
    return this.config.enabled && Boolean(this.config.bearerToken);
  }

  async fetchRecentMentions(_since: Date): Promise<SocialMention[]> {
    if (!this.isConfigured) {
      return [];
    }
    // Stub: real implementation uses X API v2 user mentions endpoint
    // https://developer.x.com/en/docs/twitter-api
    console.warn("[twitter] Stub connector — complete OAuth and implement API calls");
    return [];
  }
}

export class LinkedInConnector implements SocialConnector {
  readonly platform = "linkedin";

  constructor(private readonly config: AppConfig["social"]["linkedin"]) {}

  get isConfigured(): boolean {
    return this.config.enabled && Boolean(this.config.accessToken);
  }

  async fetchRecentMentions(_since: Date): Promise<SocialMention[]> {
    if (!this.isConfigured) {
      return [];
    }
    console.warn("[linkedin] Stub connector — complete OAuth and implement API calls");
    return [];
  }
}

export class InstagramConnector implements SocialConnector {
  readonly platform = "instagram";

  constructor(private readonly config: AppConfig["social"]["instagram"]) {}

  get isConfigured(): boolean {
    return this.config.enabled && Boolean(this.config.accessToken);
  }

  async fetchRecentMentions(_since: Date): Promise<SocialMention[]> {
    if (!this.isConfigured) {
      return [];
    }
    console.warn("[instagram] Stub connector — complete Meta Graph API setup");
    return [];
  }
}

export function createSocialConnectors(config: AppConfig): SocialConnector[] {
  return [
    new FacebookConnector(config.social.facebook, config.social.meta.appId),
    new TwitterConnector(config.social.twitter),
    new LinkedInConnector(config.social.linkedin),
    new InstagramConnector(config.social.instagram),
  ];
}
