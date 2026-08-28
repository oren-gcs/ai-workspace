import "dotenv/config";

export interface AppConfig {
  xai: {
    apiKey: string;
    apiBase: string;
    model: string;
  };
  server: {
    host: string;
    port: number;
    webhookPath: string;
    webhookSecret: string;
    publicWebhookBaseUrl: string;
  };
  runner: {
    pollIntervalMs: number;
    dryRun: boolean;
  };
  whatsapp: {
    provider: "meta" | "twilio" | "none";
    toNumber: string;
    testNumber: string;
    allowOutbound: boolean;
    meta: {
      accessToken: string;
      phoneNumberId: string;
      businessAccountId: string;
      verifyToken: string;
      appSecret: string;
    };
    twilio: {
      accountSid: string;
      authToken: string;
      from: string;
    };
  };
  social: {
    meta: {
      appId: string;
      appSecret: string;
    };
    facebook: {
      enabled: boolean;
      pageId: string;
      pageAccessToken: string;
    };
    twitter: { enabled: boolean; bearerToken: string };
    linkedin: { enabled: boolean; accessToken: string };
    instagram: { enabled: boolean; accessToken: string };
  };
  spotify: {
    enabled: boolean;
    clientId: string;
    clientSecret: string;
    redirectUri: string;
    refreshToken: string;
  };
}

function envBool(key: string, fallback = false): boolean {
  const v = process.env[key];
  if (v === undefined || v === "") return fallback;
  return v === "1" || v.toLowerCase() === "true";
}

function envInt(key: string, fallback: number): number {
  const v = process.env[key];
  if (!v) return fallback;
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : fallback;
}

/** Read first non-empty env var (supports legacy aliases). */
function envFirst(...keys: string[]): string {
  for (const key of keys) {
    const v = process.env[key];
    if (v?.trim()) return v.trim();
  }
  return "";
}

export function loadConfig(): AppConfig {
  const dryRunArg = process.argv.includes("--dry-run");
  const provider = (process.env.WHATSAPP_PROVIDER ?? "none").toLowerCase();

  return {
    xai: {
      apiKey: process.env.XAI_API_KEY ?? "",
      apiBase: process.env.XAI_API_BASE ?? "https://api.x.ai/v1",
      model: process.env.XAI_MODEL ?? "grok-3",
    },
    server: {
      host: process.env.BOT_HOST ?? "127.0.0.1",
      port: envInt("BOT_PORT", 3847),
      webhookPath: process.env.WEBHOOK_PATH ?? "/webhook/whatsapp",
      webhookSecret: process.env.WEBHOOK_SECRET ?? "",
      publicWebhookBaseUrl: process.env.PUBLIC_WEBHOOK_BASE_URL ?? "",
    },
    runner: {
      pollIntervalMs: envInt("POLL_INTERVAL_MS", 300_000),
      dryRun: dryRunArg || envBool("DRY_RUN", true),
    },
    whatsapp: {
      provider: provider === "meta" || provider === "twilio" ? provider : "none",
      toNumber: process.env.WHATSAPP_TO_NUMBER ?? "",
      testNumber: process.env.WHATSAPP_TEST_NUMBER ?? "",
      allowOutbound: envBool("ALLOW_OUTBOUND_WHATSAPP", false),
      meta: {
        accessToken: envFirst("WHATSAPP_ACCESS_TOKEN", "META_WHATSAPP_TOKEN"),
        phoneNumberId: envFirst("WHATSAPP_PHONE_NUMBER_ID", "META_WHATSAPP_PHONE_NUMBER_ID"),
        businessAccountId: envFirst(
          "WHATSAPP_BUSINESS_ACCOUNT_ID",
          "META_WHATSAPP_BUSINESS_ACCOUNT_ID"
        ),
        verifyToken: envFirst("WEBHOOK_VERIFY_TOKEN", "META_WEBHOOK_VERIFY_TOKEN"),
        appSecret: envFirst("META_APP_SECRET"),
      },
      twilio: {
        accountSid: process.env.TWILIO_ACCOUNT_SID ?? "",
        authToken: process.env.TWILIO_AUTH_TOKEN ?? "",
        from: process.env.TWILIO_WHATSAPP_FROM ?? "whatsapp:+14155238886",
      },
    },
    social: {
      meta: {
        appId: envFirst("META_APP_ID", "INSTAGRAM_APP_ID"),
        appSecret: envFirst("META_APP_SECRET", "INSTAGRAM_APP_SECRET"),
      },
      facebook: {
        enabled: envBool("ENABLE_FACEBOOK", false),
        pageId: process.env.FACEBOOK_PAGE_ID ?? "",
        pageAccessToken: process.env.FACEBOOK_PAGE_ACCESS_TOKEN ?? "",
      },
      twitter: {
        enabled: envBool("ENABLE_TWITTER", false),
        bearerToken: process.env.TWITTER_BEARER_TOKEN ?? "",
      },
      linkedin: {
        enabled: envBool("ENABLE_LINKEDIN", false),
        accessToken: process.env.LINKEDIN_ACCESS_TOKEN ?? "",
      },
      instagram: {
        enabled: envBool("ENABLE_INSTAGRAM", false),
        accessToken: process.env.INSTAGRAM_ACCESS_TOKEN ?? "",
      },
    },
    spotify: {
      enabled: envBool("ENABLE_SPOTIFY", false),
      clientId: process.env.SPOTIFY_CLIENT_ID ?? "",
      clientSecret: process.env.SPOTIFY_CLIENT_SECRET ?? "",
      redirectUri:
        process.env.SPOTIFY_REDIRECT_URI ?? "http://127.0.0.1:3847/auth/spotify/callback",
      refreshToken: process.env.SPOTIFY_REFRESH_TOKEN ?? "",
    },
  };
}

export function validateConfig(config: AppConfig): string[] {
  const issues: string[] = [];

  if (!config.xai.apiKey) {
    issues.push("XAI_API_KEY missing — Grok summarization disabled");
  }

  if (config.whatsapp.provider === "none") {
    issues.push("WHATSAPP_PROVIDER=none — notifications stub only (set WHATSAPP_PROVIDER=meta for Facebook/Meta)");
  } else if (config.whatsapp.provider === "meta") {
    if (!config.whatsapp.meta.accessToken || !config.whatsapp.meta.phoneNumberId) {
      issues.push(
        "Meta WhatsApp: set WHATSAPP_ACCESS_TOKEN and WHATSAPP_PHONE_NUMBER_ID (see docs/CONFIG-META-WHATSAPP-FACEBOOK.md)"
      );
    }
    if (!config.social.meta.appId) {
      issues.push("Meta app: set META_APP_ID from developers.facebook.com");
    }
    if (!config.whatsapp.meta.verifyToken) {
      issues.push("Meta webhook: set WEBHOOK_VERIFY_TOKEN before registering webhook in Meta Console");
    }
  } else if (config.whatsapp.provider === "twilio") {
    if (!config.whatsapp.twilio.accountSid || !config.whatsapp.twilio.authToken) {
      issues.push("Twilio: set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN");
    }
  }

  if (!config.runner.dryRun && config.whatsapp.allowOutbound) {
    if (!config.whatsapp.testNumber) {
      issues.push("ALLOW_OUTBOUND_WHATSAPP requires WHATSAPP_TEST_NUMBER");
    }
  }

  const anySocial =
    config.social.twitter.enabled ||
    config.social.linkedin.enabled ||
    config.social.instagram.enabled ||
    config.social.facebook.enabled ||
    config.spotify.enabled;
  if (!anySocial) {
    issues.push(
      "No platforms enabled — set ENABLE_FACEBOOK / ENABLE_TWITTER / ENABLE_LINKEDIN / ENABLE_INSTAGRAM / ENABLE_SPOTIFY after OAuth"
    );
  }

  if (config.spotify.enabled && !config.spotify.clientId) {
    issues.push("ENABLE_SPOTIFY=true requires SPOTIFY_CLIENT_ID (see docs/SPOTIFY-SETUP.md)");
  }

  if (config.spotify.enabled && config.spotify.clientId && !config.spotify.refreshToken) {
    issues.push(
      "Spotify: SPOTIFY_REFRESH_TOKEN missing — run scripts/spotify-auth.ps1 and complete OAuth"
    );
  }

  if (config.social.facebook.enabled && !config.social.facebook.pageAccessToken) {
    issues.push("ENABLE_FACEBOOK=true requires FACEBOOK_PAGE_ID and FACEBOOK_PAGE_ACCESS_TOKEN");
  }

  return issues;
}
