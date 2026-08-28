import type { AppConfig } from "../config.js";
import type { SocialConnector, SocialMention } from "./types.js";

const GRAPH_API_VERSION = "v21.0";

/**
 * Facebook Page connector via Meta Graph API.
 * Fetches recent Page feed posts and tagged mentions (stub until tokens are set).
 */
export class FacebookConnector implements SocialConnector {
  readonly platform = "facebook";

  constructor(
    private readonly facebook: AppConfig["social"]["facebook"],
    private readonly metaAppId: string
  ) {}

  get isConfigured(): boolean {
    return (
      this.facebook.enabled &&
      Boolean(this.facebook.pageId && this.facebook.pageAccessToken && this.metaAppId)
    );
  }

  async fetchRecentMentions(since: Date): Promise<SocialMention[]> {
    if (!this.isConfigured) {
      return [];
    }

    const { pageId, pageAccessToken } = this.facebook;
    const sinceUnix = Math.floor(since.getTime() / 1000);

    try {
      const [feedMentions, taggedMentions] = await Promise.all([
        this.fetchPageFeed(pageId, pageAccessToken, sinceUnix),
        this.fetchTaggedPosts(pageId, pageAccessToken, sinceUnix),
      ]);

      const combined = [...feedMentions, ...taggedMentions];
      const byId = new Map<string, SocialMention>();
      for (const m of combined) {
        byId.set(m.id, m);
      }
      return [...byId.values()].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.warn(`[facebook] Graph API error: ${msg}`);
      return [];
    }
  }

  private async fetchPageFeed(
    pageId: string,
    token: string,
    sinceUnix: number
  ): Promise<SocialMention[]> {
    const url = new URL(`https://graph.facebook.com/${GRAPH_API_VERSION}/${pageId}/feed`);
    url.searchParams.set("fields", "id,message,created_time,from,permalink_url");
    url.searchParams.set("since", String(sinceUnix));
    url.searchParams.set("limit", "25");
    url.searchParams.set("access_token", token);

    const res = await fetch(url);
    if (!res.ok) {
      const body = await res.text();
      throw new Error(`feed ${res.status}: ${body.slice(0, 200)}`);
    }

    const data = (await res.json()) as {
      data?: Array<{
        id: string;
        message?: string;
        created_time?: string;
        from?: { name?: string };
        permalink_url?: string;
      }>;
    };

    return (data.data ?? [])
      .filter((p) => p.message)
      .map((p) => ({
        id: p.id,
        platform: "facebook",
        author: p.from?.name ?? "page",
        text: p.message ?? "",
        url: p.permalink_url,
        createdAt: new Date(p.created_time ?? Date.now()),
      }));
  }

  private async fetchTaggedPosts(
    pageId: string,
    token: string,
    sinceUnix: number
  ): Promise<SocialMention[]> {
    const url = new URL(`https://graph.facebook.com/${GRAPH_API_VERSION}/${pageId}/tagged`);
    url.searchParams.set("fields", "id,message,created_time,from,permalink_url");
    url.searchParams.set("since", String(sinceUnix));
    url.searchParams.set("limit", "25");
    url.searchParams.set("access_token", token);

    const res = await fetch(url);
    if (!res.ok) {
      // tagged endpoint may require extra permissions — non-fatal
      console.warn(`[facebook] tagged endpoint ${res.status} — check pages_read_engagement permission`);
      return [];
    }

    const data = (await res.json()) as {
      data?: Array<{
        id: string;
        message?: string;
        created_time?: string;
        from?: { name?: string };
        permalink_url?: string;
      }>;
    };

    return (data.data ?? [])
      .filter((p) => p.message)
      .map((p) => ({
        id: `tagged:${p.id}`,
        platform: "facebook",
        author: p.from?.name ?? "unknown",
        text: p.message ?? "",
        url: p.permalink_url,
        createdAt: new Date(p.created_time ?? Date.now()),
      }));
  }
}
