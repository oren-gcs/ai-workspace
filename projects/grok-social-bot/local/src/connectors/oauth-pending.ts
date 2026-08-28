import fs from "node:fs";
import path from "node:path";
import type { SpotifyPkce } from "./spotify-auth.js";

/** In-memory PKCE state for local OAuth callback (dev only). */
const pendingAuth = new Map<string, SpotifyPkce & { createdAt: number }>();

const MAX_AGE_MS = 10 * 60 * 1000;

function pendingFilePath(): string {
  return path.resolve(process.cwd(), ".spotify-oauth-pending.json");
}

export function storePendingAuth(pkce: SpotifyPkce): void {
  pruneExpired();
  pendingAuth.set(pkce.state, { ...pkce, createdAt: Date.now() });
  try {
    fs.writeFileSync(
      pendingFilePath(),
      JSON.stringify({ ...pkce, createdAt: Date.now() }, null, 2),
      "utf8"
    );
  } catch {
    // non-fatal — in-memory still works for same-process auth
  }
}

export function consumePendingAuth(state: string): SpotifyPkce | null {
  pruneExpired();

  const entry = pendingAuth.get(state);
  if (entry) {
    pendingAuth.delete(state);
    clearPendingFile();
    return {
      codeVerifier: entry.codeVerifier,
      codeChallenge: entry.codeChallenge,
      state: entry.state,
    };
  }

  return readPendingFile(state);
}

function readPendingFile(expectedState: string): SpotifyPkce | null {
  const file = pendingFilePath();
  if (!fs.existsSync(file)) {
    return null;
  }

  try {
    const raw = JSON.parse(fs.readFileSync(file, "utf8")) as SpotifyPkce & { createdAt?: number };
    if (raw.state !== expectedState) {
      return null;
    }
    if (raw.createdAt && Date.now() - raw.createdAt > MAX_AGE_MS) {
      clearPendingFile();
      return null;
    }
    clearPendingFile();
    return {
      codeVerifier: raw.codeVerifier,
      codeChallenge: raw.codeChallenge,
      state: raw.state,
    };
  } catch {
    return null;
  }
}

function clearPendingFile(): void {
  try {
    fs.unlinkSync(pendingFilePath());
  } catch {
    // ignore
  }
}

function pruneExpired(): void {
  const now = Date.now();
  for (const [state, entry] of pendingAuth) {
    if (now - entry.createdAt > MAX_AGE_MS) {
      pendingAuth.delete(state);
    }
  }
}
