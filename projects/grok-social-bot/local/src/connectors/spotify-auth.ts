import crypto from "node:crypto";

export const SPOTIFY_AUTH_URL = "https://accounts.spotify.com/authorize";
export const SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token";

/** Scopes required for digest context — see docs/SPOTIFY-SETUP.md */
export const SPOTIFY_SCOPES = [
  "user-read-recently-played", // recent listening history for daily digest
  "user-read-currently-playing", // live "now playing" in digest
  "playlist-read-private", // private playlists for mood/context signals
  "user-top-read", // top artists/tracks over time
] as const;

export interface SpotifyPkce {
  codeVerifier: string;
  codeChallenge: string;
  state: string;
}

export interface SpotifyTokenResponse {
  access_token: string;
  token_type: string;
  scope: string;
  expires_in: number;
  refresh_token?: string;
}

export function generatePkce(): SpotifyPkce {
  const codeVerifier = crypto.randomBytes(32).toString("base64url");
  const codeChallenge = crypto
    .createHash("sha256")
    .update(codeVerifier)
    .digest("base64url");
  const state = crypto.randomBytes(16).toString("hex");
  return { codeVerifier, codeChallenge, state };
}

export function buildSpotifyAuthUrl(params: {
  clientId: string;
  redirectUri: string;
  codeChallenge: string;
  state: string;
  scopes?: readonly string[];
}): string {
  const url = new URL(SPOTIFY_AUTH_URL);
  url.searchParams.set("client_id", params.clientId);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("redirect_uri", params.redirectUri);
  url.searchParams.set("code_challenge_method", "S256");
  url.searchParams.set("code_challenge", params.codeChallenge);
  url.searchParams.set("state", params.state);
  url.searchParams.set("scope", (params.scopes ?? SPOTIFY_SCOPES).join(" "));
  return url.toString();
}

export async function exchangeCodeForTokens(params: {
  clientId: string;
  clientSecret: string;
  code: string;
  redirectUri: string;
  codeVerifier: string;
}): Promise<SpotifyTokenResponse> {
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code: params.code,
    redirect_uri: params.redirectUri,
    client_id: params.clientId,
    code_verifier: params.codeVerifier,
  });

  const headers: Record<string, string> = {
    "Content-Type": "application/x-www-form-urlencoded",
  };

  // Client secret optional for PKCE public clients; include when set
  if (params.clientSecret) {
    const basic = Buffer.from(`${params.clientId}:${params.clientSecret}`).toString("base64");
    headers.Authorization = `Basic ${basic}`;
  }

  const res = await fetch(SPOTIFY_TOKEN_URL, {
    method: "POST",
    headers,
    body,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Spotify token exchange ${res.status}: ${text.slice(0, 300)}`);
  }

  return (await res.json()) as SpotifyTokenResponse;
}

export async function refreshAccessToken(params: {
  clientId: string;
  clientSecret: string;
  refreshToken: string;
}): Promise<SpotifyTokenResponse> {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: params.refreshToken,
    client_id: params.clientId,
  });

  const headers: Record<string, string> = {
    "Content-Type": "application/x-www-form-urlencoded",
  };

  if (params.clientSecret) {
    const basic = Buffer.from(`${params.clientId}:${params.clientSecret}`).toString("base64");
    headers.Authorization = `Basic ${basic}`;
  }

  const res = await fetch(SPOTIFY_TOKEN_URL, {
    method: "POST",
    headers,
    body,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Spotify token refresh ${res.status}: ${text.slice(0, 300)}`);
  }

  return (await res.json()) as SpotifyTokenResponse;
}
