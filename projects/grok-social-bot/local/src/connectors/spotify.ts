import type { AppConfig } from "../config.js";
import { refreshAccessToken, SPOTIFY_SCOPES } from "./spotify-auth.js";

const SPOTIFY_API_BASE = "https://api.spotify.com/v1";

export interface SpotifyTrack {
  id: string;
  name: string;
  artists: string[];
  album: string;
  playedAt?: Date;
  url?: string;
}

export interface SpotifyArtist {
  id: string;
  name: string;
  genres: string[];
  url?: string;
}

export interface SpotifyNowPlaying {
  track: SpotifyTrack;
  isPlaying: boolean;
}

/**
 * Spotify Web API connector (OAuth 2.0 Authorization Code + PKCE).
 * Listening activity feeds Grok digest context — not social mentions.
 */
export class SpotifyConnector {
  readonly platform = "spotify";

  private accessToken: string | null = null;
  private accessTokenExpiresAt = 0;

  constructor(private readonly config: AppConfig["spotify"]) {}

  get isConfigured(): boolean {
    return (
      this.config.enabled &&
      Boolean(this.config.clientId && this.config.refreshToken)
    );
  }

  /** Scopes requested during OAuth — documented in docs/SPOTIFY-SETUP.md */
  static readonly scopes = SPOTIFY_SCOPES;

  async getRecentlyPlayed(limit = 20): Promise<SpotifyTrack[]> {
    if (!this.isConfigured) {
      return [];
    }

    const data = await this.apiGet<{
      items?: Array<{
        played_at?: string;
        track?: {
          id: string;
          name: string;
          artists?: Array<{ name: string }>;
          album?: { name: string };
          external_urls?: { spotify?: string };
        };
      }>;
    }>(`/me/player/recently-played?limit=${limit}`);

    return (data.items ?? [])
      .filter((item) => item.track)
      .map((item) => ({
        id: item.track!.id,
        name: item.track!.name,
        artists: (item.track!.artists ?? []).map((a) => a.name),
        album: item.track!.album?.name ?? "",
        playedAt: item.played_at ? new Date(item.played_at) : undefined,
        url: item.track!.external_urls?.spotify,
      }));
  }

  async getCurrentlyPlaying(): Promise<SpotifyNowPlaying | null> {
    if (!this.isConfigured) {
      return null;
    }

    const res = await this.authenticatedFetch(`${SPOTIFY_API_BASE}/me/player/currently-playing`);

    if (res.status === 204) {
      return null;
    }

    if (!res.ok) {
      const body = await res.text();
      console.warn(`[spotify] currently-playing ${res.status}: ${body.slice(0, 200)}`);
      return null;
    }

    const data = (await res.json()) as {
      is_playing?: boolean;
      item?: {
        id: string;
        name: string;
        artists?: Array<{ name: string }>;
        album?: { name: string };
        external_urls?: { spotify?: string };
      };
    };

    if (!data.item) {
      return null;
    }

    return {
      isPlaying: data.is_playing ?? false,
      track: {
        id: data.item.id,
        name: data.item.name,
        artists: (data.item.artists ?? []).map((a) => a.name),
        album: data.item.album?.name ?? "",
        url: data.item.external_urls?.spotify,
      },
    };
  }

  async getTopArtists(limit = 10): Promise<SpotifyArtist[]> {
    if (!this.isConfigured) {
      return [];
    }

    const data = await this.apiGet<{
      items?: Array<{
        id: string;
        name: string;
        genres?: string[];
        external_urls?: { spotify?: string };
      }>;
    }>(`/me/top/artists?limit=${limit}&time_range=short_term`);

    return (data.items ?? []).map((a) => ({
      id: a.id,
      name: a.name,
      genres: a.genres ?? [],
      url: a.external_urls?.spotify,
    }));
  }

  /** Format listening activity as digest lines for Grok */
  async fetchDigestLines(): Promise<string[]> {
    if (!this.isConfigured) {
      return [];
    }

    const lines: string[] = [];

    try {
      const now = await this.getCurrentlyPlaying();
      if (now) {
        const artists = now.track.artists.join(", ");
        const status = now.isPlaying ? "Now playing" : "Paused on";
        lines.push(`[spotify] ${status}: ${now.track.name} — ${artists}`);
      }

      const recent = await this.getRecentlyPlayed(10);
      for (const track of recent) {
        const artists = track.artists.join(", ");
        const when = track.playedAt ? track.playedAt.toISOString() : "";
        lines.push(`[spotify] Recent: ${track.name} — ${artists}${when ? ` (${when})` : ""}`);
      }

      const top = await this.getTopArtists(5);
      if (top.length > 0) {
        const names = top.map((a) => a.name).join(", ");
        lines.push(`[spotify] Top artists (short term): ${names}`);
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.warn(`[spotify] digest fetch error: ${msg}`);
    }

    return lines;
  }

  private async ensureAccessToken(): Promise<string> {
    if (this.accessToken && Date.now() < this.accessTokenExpiresAt - 60_000) {
      return this.accessToken;
    }

    const { clientId, clientSecret, refreshToken } = this.config;
    if (!refreshToken) {
      throw new Error("SPOTIFY_REFRESH_TOKEN not set");
    }

    const tokens = await refreshAccessToken({ clientId, clientSecret, refreshToken });
    this.accessToken = tokens.access_token;
    this.accessTokenExpiresAt = Date.now() + tokens.expires_in * 1000;
    return this.accessToken;
  }

  private async authenticatedFetch(url: string): Promise<Response> {
    const token = await this.ensureAccessToken();
    return fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
  }

  private async apiGet<T>(path: string): Promise<T> {
    const res = await this.authenticatedFetch(`${SPOTIFY_API_BASE}${path}`);
    if (!res.ok) {
      const body = await res.text();
      throw new Error(`${path} ${res.status}: ${body.slice(0, 200)}`);
    }
    return (await res.json()) as T;
  }
}

export function createSpotifyConnector(config: AppConfig): SpotifyConnector | null {
  if (!config.spotify.enabled) {
    return null;
  }
  return new SpotifyConnector(config.spotify);
}
